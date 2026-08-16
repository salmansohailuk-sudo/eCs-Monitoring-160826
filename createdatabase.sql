#-- Create the database
CREATE DATABASE IF NOT EXISTS ecomm;

#-- Select the database
USE ecomm;

#-- Orders table (successful payments only)
CREATE TABLE IF NOT EXISTS orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    session_id VARCHAR(255),
    amount INT,
    status VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

#-- Analytics table (visitor events, cancellations, failures, etc.)
CREATE TABLE IF NOT EXISTS analytics (
    id INT AUTO_INCREMENT PRIMARY KEY,
    event_type VARCHAR(50),
    session_id VARCHAR(255) NULL,
    user_agent TEXT,
    ip_address VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

#-- Geo tracking table (IP → country → city → lat/long)
CREATE TABLE IF NOT EXISTS geo_tracking (
    id INT AUTO_INCREMENT PRIMARY KEY,
    ip VARCHAR(50),
    city VARCHAR(100),
    region VARCHAR(100),
    country VARCHAR(100),
    latitude VARCHAR(50),
    longitude VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


