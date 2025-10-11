from flask import Flask, render_template, request, redirect, url_for, Response
import mysql.connector
from minio import Minio
from minio.error import S3Error
import os
import uuid

app = Flask(__name__)

minio_client = Minio(
    os.environ.get("MINIO_ENDPOINT", "minio-service:9000"),
    access_key=os.environ.get("MINIO_ROOT_USER", "minioadmin"),  # Updated
    secret_key=os.environ.get("MINIO_ROOT_PASSWORD", "minioadmin123"),  # Updated
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

def get_dogs():
    connection = mysql.connector.connect(**db_config)
    cursor = connection.cursor(dictionary=True)
    cursor.execute("SELECT id, name, breed, age, img_url FROM dogs")
    dogs = cursor.fetchall()
    cursor.close()
    connection.close()
    return dogs

def add_dog(name, breed, age, image_file):
    img_url = "/static/images/default.jpg"  # default
    
    if image_file and image_file.filename:
        # Generate unique filename to prevent conflicts
        ext = image_file.filename.rsplit('.', 1)[1].lower() if '.' in image_file.filename else 'jpg'
        filename = f"{uuid.uuid4()}.{ext}"
        
        try:
            # Upload to MinIO
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
    
    connection = mysql.connector.connect(**db_config)
    cursor = connection.cursor()
    cursor.execute(
        "INSERT INTO dogs (name, breed, age, img_url) VALUES (%s, %s, %s, %s)",
        (name, breed, age, img_url)
    )
    connection.commit()
    cursor.close()
    connection.close()

@app.route("/")
def index():
    dogs = get_dogs()
    return render_template("index.html", dogs=dogs)

@app.route("/manage", methods=["GET", "POST"])
def manage():
    if request.method == "POST":
        name = request.form["name"]
        breed = request.form["breed"]
        age = request.form["age"]
        file = request.files.get("image")
        
        add_dog(name, breed, age, file)
        return redirect(url_for("index"))
    
    return render_template("manage.html")

@app.route("/images/<filename>")
def serve_image(filename):
    """Proxy images from MinIO - users never see MinIO directly"""
    try:
        response = minio_client.get_object(BUCKET_NAME, filename)
        
        # Determine content type
        ext = filename.rsplit('.', 1)[1].lower() if '.' in filename else 'jpg'
        content_type = f'image/{ext}'
        
        return Response(
            response.read(),
            mimetype=content_type,
            headers={
                'Cache-Control': 'public, max-age=31536000',  # Cache for 1 year
            }
        )
    except S3Error as e:
        print(f"Error retrieving image: {e}")
        return "Image not found", 404
    finally:
        response.close()
        response.release_conn()


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0")
