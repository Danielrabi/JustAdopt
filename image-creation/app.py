from flask import Flask, render_template, request, redirect, url_for, Response, g
import mysql.connector
from mysql.connector import Error as MySQLError
from minio import Minio
from minio.error import S3Error
import os
import uuid

app = Flask(__name__)

# Initialize MinIO client but DON'T connect yet
minio_client = Minio(
    os.environ.get("MINIO_ENDPOINT", "minio-service:9000"),
    access_key=os.environ.get("MINIO_ROOT_USER", "minioadmin"),
    secret_key=os.environ.get("MINIO_ROOT_PASSWORD", "minioadmin123"),
    secure=False
)

BUCKET_NAME = "dog-images"
MINIO_AVAILABLE = False
MINIO_CHECKED = False

def init_minio():
    """Initialize MinIO bucket - called lazily with timeout"""
    global MINIO_AVAILABLE, MINIO_CHECKED
    
    if MINIO_CHECKED and MINIO_AVAILABLE:
        return True  # Already initialized successfully
    
    try:
        # Set a short timeout to avoid hanging
        import socket
        original_timeout = socket.getdefaulttimeout()
        socket.setdefaulttimeout(2.0)  # 2 second timeout
        
        if not minio_client.bucket_exists(BUCKET_NAME):
            minio_client.make_bucket(BUCKET_NAME)
            print(f"✓ Created MinIO bucket: {BUCKET_NAME}")
        else:
            print(f"✓ MinIO bucket exists: {BUCKET_NAME}")
        
        MINIO_AVAILABLE = True
        MINIO_CHECKED = True
        socket.setdefaulttimeout(original_timeout)
        return True
    except Exception as e:
        print(f"✗ MinIO unavailable: {type(e).__name__}: {str(e)[:100]}")
        MINIO_AVAILABLE = False
        MINIO_CHECKED = True
        return False

db_config = {
    "host": os.environ.get("DB_HOST", "localhost"),
    "user": os.environ.get("DB_USER", "root"),
    "password": os.environ.get("DB_PASSWORD", "example"),
    "database": os.environ.get("DB_NAME", "dog_adoption"),
}

def get_db_connection():
    """Get database connection with error handling"""
    try:
        connection = mysql.connector.connect(**db_config)
        return connection
    except MySQLError as e:
        print(f"Error connecting to MySQL: {e}")
        return None

def get_dogs():
    connection = get_db_connection()
    if not connection:
        return []
    
    try:
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT id, name, breed, age, img_url FROM dogs")
        dogs = cursor.fetchall()
        cursor.close()
        return dogs
    except MySQLError as e:
        print(f"Error fetching dogs: {e}")
        return []
    finally:
        connection.close()

def add_dog(name, breed, age, image_file):
    img_url = "/static/images/default.jpg"  # default
    
    # Try MinIO first if available
    if image_file and image_file.filename:
        # Ensure MinIO is initialized
        if not MINIO_CHECKED:
            init_minio()
        
        if MINIO_AVAILABLE:
            ext = image_file.filename.rsplit('.', 1)[1].lower() if '.' in image_file.filename else 'jpg'
            filename = f"{uuid.uuid4()}.{ext}"
            
            try:
                image_file.seek(0, os.SEEK_END)
                file_size = image_file.tell()
                image_file.seek(0)
                
                minio_client.put_object(
                    BUCKET_NAME,
                    filename,
                    image_file,
                    length=file_size,
                    content_type=f'image/{ext}'
                )
                img_url = f"/images/{filename}"
                print(f"✓ Uploaded image to MinIO: {filename}")
            except S3Error as e:
                print(f"✗ Error uploading to MinIO: {e}")
        else:
            print("✗ MinIO unavailable, using default image")
    
    connection = get_db_connection()
    if not connection:
        return False
    
    try:
        cursor = connection.cursor()
        cursor.execute(
            "INSERT INTO dogs (name, breed, age, img_url) VALUES (%s, %s, %s, %s)",
            (name, breed, age, img_url)
        )
        connection.commit()
        cursor.close()
        return True
    except MySQLError as e:
        print(f"Error adding dog: {e}")
        return False
    finally:
        connection.close()

@app.route("/")
def index():
    # Lazy init MinIO on actual user requests (not probes)
    if not MINIO_CHECKED and request.headers.get('User-Agent', '').lower() != 'kube-probe':
        init_minio()
    
    dogs = get_dogs()
    db_error = len(dogs) == 0 and not check_db_health()
    minio_error = MINIO_CHECKED and not MINIO_AVAILABLE
    
    return render_template("index.html", dogs=dogs, db_error=db_error, minio_error=minio_error)

@app.route("/manage", methods=["GET", "POST"])
def manage():
    # Ensure MinIO is checked before showing the form
    if not MINIO_CHECKED:
        init_minio()
    
    if request.method == "POST":
        name = request.form.get("name", "").strip()
        breed = request.form.get("breed", "").strip()
        age = request.form.get("age", "").strip()
        file = request.files.get("image")
        
        # Validate inputs
        if not name or not breed or not age:
            return render_template("manage.html", 
                                 error="All fields are required.",
                                 minio_available=MINIO_AVAILABLE,
                                 minio_checked=MINIO_CHECKED)
        
        try:
            age = int(age)
            if age < 0:
                raise ValueError("Age must be positive")
        except ValueError:
            return render_template("manage.html", 
                                 error="Age must be a valid positive number.",
                                 minio_available=MINIO_AVAILABLE,
                                 minio_checked=MINIO_CHECKED)
        
        success = add_dog(name, breed, age, file)
        
        if not success:
            return render_template("manage.html", 
                                 error="Failed to add dog. Database connection error.",
                                 minio_available=MINIO_AVAILABLE,
                                 minio_checked=MINIO_CHECKED)
        
        # Show warning if MinIO is unavailable
        if MINIO_CHECKED and not MINIO_AVAILABLE:
            return render_template("manage.html", 
                                 warning="Dog added successfully! Note: MinIO storage is unavailable, so a default image was used.",
                                 success=True,
                                 minio_available=MINIO_AVAILABLE,
                                 minio_checked=MINIO_CHECKED)
        
        return redirect(url_for("index"))
    
    # GET request - show the form
    return render_template("manage.html", 
                         minio_available=MINIO_AVAILABLE,
                         minio_checked=MINIO_CHECKED)

@app.route("/images/<filename>")
def serve_image(filename):
    """Proxy images from MinIO"""
    if not MINIO_CHECKED:
        init_minio()
    
    if not MINIO_AVAILABLE:
        return "MinIO service unavailable", 503
    
    try:
        response = minio_client.get_object(BUCKET_NAME, filename)
        
        ext = filename.rsplit('.', 1)[1].lower() if '.' in filename else 'jpg'
        content_type = f'image/{ext}'
        
        image_data = response.read()
        response.close()
        response.release_conn()
        
        return Response(
            image_data,
            mimetype=content_type,
            headers={
                'Cache-Control': 'public, max-age=31536000',
            }
        )
    except S3Error as e:
        print(f"Error retrieving image: {e}")
        return "Image not found", 404
    except Exception as e:
        print(f"Unexpected error serving image: {e}")
        return "Error loading image", 500

@app.route("/health")
def health():
    """Health check endpoint - doesn't require MinIO"""
    db_healthy = check_db_health()
    
    status = {
        "status": "healthy" if db_healthy else "degraded",
        "database": "connected" if db_healthy else "disconnected",
        "minio": "connected" if MINIO_AVAILABLE else ("unchecked" if not MINIO_CHECKED else "disconnected")
    }
    
    # Return 200 if DB is healthy (app can run without MinIO)
    status_code = 200 if db_healthy else 503
    return status, status_code

@app.route("/readiness")
def readiness():
    """Readiness check - app is ready if DB is available"""
    db_healthy = check_db_health()
    return ("Ready" if db_healthy else "Not Ready"), (200 if db_healthy else 503)

def check_db_health():
    """Check if database is reachable"""
    try:
        connection = mysql.connector.connect(**db_config, connect_timeout=2)
        connection.close()
        return True
    except Exception:
        return False

if __name__ == "__main__":
    print("=" * 50)
    print("Starting Flask application...")
    print(f"DB_HOST: {os.environ.get('DB_HOST', 'localhost')}")
    print(f"MINIO_ENDPOINT: {os.environ.get('MINIO_ENDPOINT', 'minio-service:9000')}")
    print("MinIO will be initialized on first user request")
    print("=" * 50)
    
    app.run(debug=True, host="0.0.0.0")