"""
email.py - A helper module for sending emails.
"""


import os
import smtplib
from email.mime.text import MIMEText
from dotenv import load_dotenv


def send_email(email, subject, body):
    """
        Sends an email to the specified recipient with the given subject and body.

        Args:
            email (str): The recipient's email address.
            subject (str): The subject of the email.
            body (str): The body content of the email.

        Returns:
            None
    """
    try:
        load_dotenv()
        info = {
            'server': os.getenv('FLASK_SMTP_SERVER'),
            'port': int(os.getenv('FLASK_SMTP_PORT')),
            'address': os.getenv('FLASK_EMAIL_ADDRESS'),
            'password': os.getenv('FLASK_EMAIL_PASS')
        }
        msg = MIMEText(body)
        msg["Subject"] = subject
        msg["From"] = info['address']
        msg["To"] = email

        with smtplib.SMTP(info['server'], info['port']) as server:
            server.starttls()
            server.login(info['address'], info['password'])
            server.sendmail(info['address'], email, msg.as_string())
    except (ValueError, KeyError) as e:
        print(f"Specific error occurred: {e}")
