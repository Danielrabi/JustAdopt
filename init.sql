CREATE TABLE dogs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    breed VARCHAR(100),
    age INT,
    img_url VARCHAR(255)
);

INSERT INTO dogs (name, breed, age, img_url) VALUES
('Lucy', 'Bulldog', 4, '/static/images/1.jpeg'),
('Buddy', 'Beagle', 2, '/static/images/2.jpeg'),
('Bella', 'German Shepherd', 5, '/static/images/3.jpeg'),
('Max', 'Poodle', 1, '/static/images/4.jpeg');