import time
import os
import logging
import traceback
from flask import Flask, request, jsonify, Response
import stripe
import mysql.connector

from prometheus_client import (
    generate_latest,
    CONTENT_TYPE_LATEST,
    Counter,
    Histogram
)

app = Flask(__name__)

# ----------------------------------------------------
# Prometheus Metrics Definitions
# ----------------------------------------------------
HTTP_REQUESTS = Counter(
    "flask_http_requests_total",
    "Total HTTP requests",
    ["method", "endpoint", "status"]
)

HTTP_REQUEST_DURATION = Histogram(
    "flask_http_request_duration_seconds",
    "HTTP request duration in seconds",
    ["method", "endpoint"]
)

# Request Hooks for Automated Scrape Recording
@app.before_request
def before_request():
    request._start_time = time.time()

@app.after_request
def after_request(response):
    if request.endpoint != "metrics":
        duration = time.time() - getattr(request, "_start_time", time.time())
        endpoint = request.endpoint or "unknown"
        
        HTTP_REQUESTS.labels(
            method=request.method,
            endpoint=endpoint,
            status=response.status_code
        ).inc()
        
        HTTP_REQUEST_DURATION.labels(
            method=request.method,
            endpoint=endpoint
        ).observe(duration)
        
    return response

# ----------------------------------------------------
# Logging Configuration
# ----------------------------------------------------
logging.basicConfig(level=logging.INFO)

# ----------------------------------------------------
# Environment Variables
# ----------------------------------------------------
stripe.api_key = os.getenv("STRIPE_SECRET_KEY")
WEBHOOK_SECRET = os.getenv("STRIPE_WEBHOOK_SECRET")

BASE_URL = os.getenv("BASE_URL", "http://localhost:5000")

DB_HOST = os.getenv("DB_HOST")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_NAME = os.getenv("DB_NAME")

app.logger.info("===================================")
app.logger.info("Backend Starting")
app.logger.info(f"DB_HOST          : {DB_HOST}")
app.logger.info(f"DB_NAME          : {DB_NAME}")
app.logger.info(f"Stripe Loaded    : {bool(stripe.api_key)}")
app.logger.info(f"Webhook Loaded   : {bool(WEBHOOK_SECRET)}")
app.logger.info(f"BASE_URL         : {BASE_URL}")
app.logger.info("===================================")

# ----------------------------------------------------
# Database Connection
# ----------------------------------------------------
def get_db_connection():
    return mysql.connector.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME
    )

# ----------------------------------------------------
# Save Analytics Event
# ----------------------------------------------------
def save_event(event_type, session_id=None):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute("""
            INSERT INTO analytics (event_type, session_id, user_agent, ip_address)
            VALUES (%s, %s, %s, %s)
        """, (
            event_type,
            session_id,
            request.headers.get("User-Agent"),
            request.remote_addr
        ))

        conn.commit()
        cursor.close()
        conn.close()

    except Exception as e:
        app.logger.error("Analytics Save Error")
        app.logger.error(str(e))

# ----------------------------------------------------
# Geo Tracking Endpoint
# ----------------------------------------------------
@app.post("/api/track-geo")
def track_geo():
    data = request.json or {}

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute("""
            INSERT INTO geo_tracking (ip, city, region, country, latitude, longitude)
            VALUES (%s, %s, %s, %s, %s, %s)
        """, (
            data.get("ip"),
            data.get("city"),
            data.get("region"),
            data.get("country"),
            data.get("latitude"),
            data.get("longitude")
        ))

        conn.commit()
        cursor.close()
        conn.close()

        save_event("geo_location")

    except Exception as e:
        app.logger.error("Geo Tracking Error")
        app.logger.error(str(e))

    return jsonify({"status": "ok"})

# ----------------------------------------------------
# Save Order Logic
# ----------------------------------------------------
def save_order(session):
    conn = None
    cursor = None

    try:
        app.logger.info("========== SAVING ORDER ==========")
        app.logger.info(f"Session ID : {session['id']}")
        app.logger.info(f"Amount     : {session['amount_total']}")

        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute(
            "SELECT COUNT(*) FROM orders WHERE session_id=%s",
            (session["id"],)
        )
        exists = cursor.fetchone()[0]

        if exists:
            app.logger.info("Order already exists. Skipping insert.")
            return

        cursor.execute(
            """
            INSERT INTO orders
            (session_id, amount, status)
            VALUES (%s,%s,%s)
            """,
            (
                session["id"],
                session["amount_total"],
                "paid"
            )
        )

        conn.commit()

        app.logger.info(f"Rows Inserted : {cursor.rowcount}")
        app.logger.info("Order Saved Successfully")

    except Exception as e:
        app.logger.error("Database Error")
        app.logger.error(str(e))
        app.logger.error(traceback.format_exc())

    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

# ----------------------------------------------------
# Prometheus Metrics Endpoint
# ----------------------------------------------------
@app.route("/metrics")
def metrics():
    return Response(
        generate_latest(),
        mimetype=CONTENT_TYPE_LATEST
    )

# ----------------------------------------------------
# Health Check Endpoint
# ----------------------------------------------------
@app.route('/health')
def health():
    return jsonify({"status": "ok"})

# ----------------------------------------------------
# Tracking Routes
# ----------------------------------------------------
@app.post("/api/track-visit")
def track_visit():
    save_event("page_visit")
    return jsonify({"status": "ok"})

@app.post("/api/track-start-checkout")
def track_start_checkout():
    save_event("start_checkout")
    return jsonify({"status": "ok"})

@app.post("/api/track-cancel")
def track_cancel():
    save_event("cancel_checkout")
    return jsonify({"status": "ok"})

@app.post("/api/track-success")
def track_success():
    save_event("payment_success_page")
    return jsonify({"status": "ok"})

# ----------------------------------------------------
# Stripe Routes
# ----------------------------------------------------
@app.post("/api/create-checkout-session")
def create_checkout_session():
    try:
        checkout_session = stripe.checkout.Session.create(
            payment_method_types=["card"],
            mode="payment",
            line_items=[
                {
                    "price_data": {
                        "currency": "gbp",
                        "product_data": {"name": "Wireless Headphones"},
                        "unit_amount": 4999
                    },
                    "quantity": 1
                }
            ],
            success_url=f"{BASE_URL}/success.html",
            cancel_url=f"{BASE_URL}/cancel.html"
        )

        app.logger.info(f"Stripe Session Created : {checkout_session.id}")

        return jsonify({"sessionId": checkout_session.id}), 200

    except Exception as e:
        app.logger.error("Checkout Session Error")
        app.logger.error(traceback.format_exc())
        return jsonify({"error": str(e)}), 500

@app.post("/api/webhook")
def stripe_webhook():
    app.logger.info("========================================")
    app.logger.info("WEBHOOK RECEIVED")
    app.logger.info("========================================")

    payload = request.data
    signature = request.headers.get("Stripe-Signature")

    if not signature:
        app.logger.error("Missing Stripe Signature")
        return "Missing Stripe Signature", 400

    try:
        event = stripe.Webhook.construct_event(
            payload,
            signature,
            WEBHOOK_SECRET
        )
        app.logger.info(f"Event Type : {event['type']}")

    except Exception as e:
        app.logger.error("Webhook Verification Failed")
        app.logger.error(str(e))
        return "Webhook Verification Failed", 400

    event_type = event["type"]
    data = event["data"]["object"]

    if event_type == "checkout.session.completed":
        save_order(data)
        save_event("payment_success", data["id"])
    elif event_type == "checkout.session.expired":
        save_event("checkout_expired", data["id"])
    elif event_type == "payment_intent.payment_failed":
        save_event("payment_failed", data["id"])
    else:
        app.logger.info(f"Ignoring Event : {event_type}")

    return "OK", 200

# ----------------------------------------------------
# Root
# ----------------------------------------------------
@app.get("/")
def root():
    return jsonify({
        "application": "E-Commerce Backend",
        "status": "running"
    })

if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=5000,
        debug=True
    )
