"""Utilidad de notificaciones por correo electronico para la wallet multicadena.
Envua correos SMTP con soporte TLS para notificar inicios de sesion y registros.
Si SMTP no esta configurado, los correos se omiten silenciosamente.
"""

import smtplib
import logging
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from app.config import get_settings

logger = logging.getLogger(__name__)


def send_email(to_email: str, subject: str, body: str):
    """Envia un correo electronico si SMTP esta configurado"""
    settings = get_settings()
    if not settings.smtp_user or not settings.smtp_password:
        logger.info(f"Correo omitido (SMTP no configurado): {subject} -> {to_email}")
        return

    try:
        msg = MIMEMultipart()
        msg["From"] = settings.smtp_user
        msg["To"] = to_email
        msg["Subject"] = subject
        msg.attach(MIMEText(body, "plain", "utf-8"))

        with smtplib.SMTP(settings.smtp_host, settings.smtp_port) as server:
            server.starttls()
            server.login(settings.smtp_user, settings.smtp_password)
            server.send_message(msg)

        logger.info(f"Correo enviado a {to_email}: {subject}")
    except Exception as e:
        logger.warning(f"Error al enviar correo a {to_email}: {e}")
