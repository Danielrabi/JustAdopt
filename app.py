from flask import Flask, render_template
import mysql.connector
import os

app = Flask(__name__)

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

@app.route("/")
def index():
    dogs = get_dogs()
    return render_template("index.html", dogs=dogs)

if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0")
