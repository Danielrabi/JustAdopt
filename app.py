from flask import Flask, render_template, request, redirect, url_for, Response, g
import mysql.connector
from mysql.connector import Error as MySQLError
import boto3
from botocore.exceptions import ClientError
import os
import uuid

app = Flask(__name__)

# Get S3 bucket name from environment variable (injected by Argo CD)
S3_BUCKET_NAME = os.environ.get("S3_BUCKET_NAME")
S3_CLIENT = None
S3_AVAILABLE = False

# Get DB config
db_config = {
    "host": os.environ.get("DB_HOST", "localhost"),
    "user": os.environ.get("DB_USER", "root"),
    "password": os.environ.get("DB_PASSWORD", "example"),
    "database": os.environ.get("DB_NAME", "dog_adoption"),
}

def init_db():
    """Initialize the database and create tables if they don't exist."""
    create_table_sql = """
    CREATE TABLE IF NOT EXISTS dogs (
      id INT AUTO_INCREMENT PRIMARY KEY,
      name VARCHAR(100),
      breed VARCHAR(100),
      age INT,
      img_url VARCHAR(255)
    );
    """
    try:
        print("Connecting to database to initialize schema...")
        connection = mysql.connector.connect(**db_config)
        cursor = connection.cursor()
        cursor.execute(create_table_sql)
        connection.commit()
        cursor.close()
        connection.close()
        print("✓ Database schema initialized.")
    except MySQLError as e:
        print(f"✗ FAILED to initialize database schema: {e}")
        pass

def init_s3():
    """Initialize S3 client and check connection"""
    global S3_CLIENT, S3_AVAILABLE
    if S3_BUCKET_NAME:
        try:
            S3_CLIENT = boto3.client("s3", region_name="us-east-1")
            S3_CLIENT.head_bucket(Bucket=S3_BUCKET_NAME)
            print(f"✓ Connected to S3 bucket: {S3_BUCKET_NAME}")
            S3_AVAILABLE = True
        except ClientError as e:
            print(f"✗ Failed to connect to S3: {e}")
            S3_AVAILABLE = False
    else:
        print("✗ S3_BUCKET_NAME environment variable not set.")
        S3_AVAILABLE = False

def get_db_connection():
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

        # --- NEW S3 LOGIC ---
        # Generate pre-signed URLs for images stored in S3
        if S3_AVAILABLE:
            for dog in dogs:
                if dog["img_url"] and not dog["img_url"].startswith("/static/"):
                    try:
                        dog["img_url"] = S3_CLIENT.generate_presigned_url(
                            'get_object',
                            Params={'Bucket': S3_BUCKET_NAME, 'Key': dog["img_url"]},
                            ExpiresIn=3600  # URL is valid for 1 hour
                        )
                    except ClientError as e:
                        print(f"Error generating pre-signed URL: {e}")
                        dog["img_url"] = "/static/images/default.jpg"
        # --------------------

        return dogs
    except MySQLError as e:
        print(f"Error fetching dogs: {e}")
        return []
    finally:
        connection.close()

def add_dog(name, breed, age, image_file):
    img_key = None  # This will be the S3 object key (filename)

    # Try to upload to S3 if available
    if image_file and image_file.filename and S3_AVAILABLE:
        ext = image_file.filename.rsplit('.', 1)[1].lower() if '.' in image_file.filename else 'jpg'
        img_key = f"{uuid.uuid4()}.{ext}" # e.g., "123e4567.jpg"

        try:
            S3_CLIENT.upload_fileobj(
                image_file,
                S3_BUCKET_NAME,
                img_key,
                ExtraArgs={'ContentType': image_file.content_type}
            )
            print(f"✓ Uploaded image to S3: {img_key}")
        except ClientError as e:
            print(f"✗ Error uploading to S3: {e}")
            img_key = None

    # If upload failed or no file, use default
    if not img_key:
        img_key = "/static/images/default.jpg" # Use the key for the default image
        if S3_AVAILABLE:
            print("✗ S3 upload failed or no file, using default image.")
        else:
            print("✗ S3 unavailable, using default image.")

    connection = get_db_connection()
    if not connection:
        return False

    try:
        cursor = connection.cursor()
        # Store the S3 Key (filename) in the DB, not a full URL
        cursor.execute(
            "INSERT INTO dogs (name, breed, age, img_url) VALUES (%s, %s, %s, %s)",
            (name, breed, age, img_key)
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
    dogs = get_dogs()
    db_error = len(dogs) == 0 and not check_db_health()
    s3_error = not S3_AVAILABLE

    # FIX: Pass the 's3_error' variable
    return render_template("index.html", dogs=dogs, db_error=db_error, s3_error=s3_error)

@app.route("/manage", methods=["GET", "POST"])
def manage():
    if request.method == "POST":
        name = request.form.get("name", "").strip()
        breed = request.form.get("breed", "").strip()
        age = request.form.get("age", "").strip()
        file = request.files.get("image")

        if not name or not breed or not age:
             # FIX: Pass 's3_available'
             return render_template("manage.html", error="All fields are required.", s3_available=S3_AVAILABLE)

        try:
            age_int = int(age)
            if age_int < 0:
                raise ValueError("Age must be positive")
        except ValueError:
            # FIX: Pass 's3_available'
            return render_template("manage.html", error="Age must be a valid number.", s3_available=S3_AVAILABLE)

        success = add_dog(name, breed, age_int, file)

        if not success:
            # FIX: Pass 's3_available'
            return render_template("manage.html", error="Failed to add dog. Database connection error.", s3_available=S3_AVAILABLE)

        if not S3_AVAILABLE:
            # FIX: Pass 's3_available'
            return render_template("manage.html", warning="Dog added! Note: S3 storage is unavailable, default image was used.", success=True, s3_available=S3_AVAILABLE)

        return redirect(url_for("index"))

    # GET request - show the form
    # FIX: Pass 's3_available'
    return render_template("manage.html", s3_available=S3_AVAILABLE)

@app.route("/health")
def health():
    db_healthy = check_db_health()
    status = {
        "status": "healthy" if db_healthy else "degraded",
        "database": "connected" if db_healthy else "disconnected",
        "s3": "connected" if S3_AVAILABLE else "disconnected"
    }
    status_code = 200 if db_healthy else 503
    return status, status_code

@app.route("/readiness")
def readiness():
    db_healthy = check_db_health()
    return ("Ready" if db_healthy else "Not Ready"), (200 if db_healthy else 503)

def check_db_health():
    # ... (This function is perfect, no changes needed) ...
    try:
        connection = mysql.connector.connect(**db_config, connect_timeout=2)
        connection.close()
        return True
    except Exception:
        return False

init_db()
init_s3()

if __name__ == "__main__":
    print("=" * 50)
    print("Starting Flask application...")
    print(f"DB_HOST: {os.environ.get('DB_HOST', 'localhost')}")
    print(f"S3_BUCKET_NAME: {S3_BUCKET_NAME}")
    print("=" * 50)
    app.run(debug=True, host="0.0.0.0")