from flask import Flask, render_template, request, redirect, url_for
import mysql.connector
import os

app = Flask(__name__)

# where to save uploaded files
UPLOAD_FOLDER = "/usr/src/app/static/images"
app.config["UPLOAD_FOLDER"] = UPLOAD_FOLDER
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

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

def add_dog(name, breed, age, image_filename):
    connection = mysql.connector.connect(**db_config)
    cursor = connection.cursor()
    cursor.execute(
        "INSERT INTO dogs (name, breed, age, img_url) VALUES (%s, %s, %s, %s)",
        (name, breed, age, f"/static/images/{image_filename}")
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

        if file and file.filename != "":
            filename = file.filename
            filepath = os.path.join(app.config["UPLOAD_FOLDER"], filename)
            file.save(filepath)
        else:
            filename = "default.jpg"  # default image if none uploaded

        add_dog(name, breed, age, filename)
        return redirect(url_for("index"))

    return render_template("manage.html")


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0")
