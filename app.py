from flask import Flask, render_template, request, redirect, url_for, Response
import mysql.connector
from mysql.connector import Error as MySQLError
from minio import Minio
from minio.error import S3Error
import os
import uuid

app = Flask(__name__)

minio_client = Minio(
    os.environ.get("MINIO_ENDPOINT", "minio-service:9000"),
    access_key=os.environ.get("MINIO_ROOT_USER", "minioadmin"),
    secret_key=os.environ.get("MINIO_ROOT_PASSWORD", "minioadmin123"),
    secure=False
)

BUCKET_NAME = "dog-images"

# Ensure bucket exists
try:
    if not minio_client.bucket_exists(BUCKET_NAME):
        minio_client.make_bucket(BUCKET_NAME)
except S3Error as e:
    print(f"Error creating bucket: {e}")

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
    
    if image_file and image_file.filename:
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
        except S3Error as e:
            print(f"Error uploading to MinIO: {e}")
    
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
    dogs = get_dogs()
    db_error = len(dogs) == 0 and not check_db_health()
    return render_template("index.html", dogs=dogs, db_error=db_error)

@app.route("/manage", methods=["GET", "POST"])
def manage():
    if request.method == "POST":
        name = request.form["name"]
        breed = request.form["breed"]
        age = request.form["age"]
        file = request.files.get("image")
        
        success = add_dog(name, breed, age, file)
        if not success:
            return render_template("manage.html", error="Failed to add dog. Database connection error.")
        
        return redirect(url_for("index"))
    
    return render_template("manage.html")

@app.route("/images/<filename>")
def serve_image(filename):
    """Proxy images from MinIO - users never see MinIO directly"""
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
    """Health check endpoint"""
    db_healthy = check_db_health()
    minio_healthy = check_minio_health()
    
    status = {
        "status": "healthy" if (db_healthy and minio_healthy) else "unhealthy",
        "database": "connected" if db_healthy else "disconnected",
        "minio": "connected" if minio_healthy else "disconnected"
    }
    
    status_code = 200 if (db_healthy and minio_healthy) else 503
    return status, status_code

def check_db_health():
    """Check if database is reachable"""
    connection = get_db_connection()
    if connection:
        connection.close()
        return True
    return False

def check_minio_health():
    """Check if MinIO is reachable"""
    try:
        minio_client.bucket_exists(BUCKET_NAME)
        return True
    except Exception:
        return False

if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0")