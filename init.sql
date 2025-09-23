CREATE TABLE dogs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    breed VARCHAR(100),
    age INT
);

INSERT INTO dogs (name, breed, age) VALUES
('Lucy', 'Bulldog', 4),
('Buddy', 'Beagle', 2),
('Bella', 'German Shepherd', 5),
('Max', 'Poodle', 1);