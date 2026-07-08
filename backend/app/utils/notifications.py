import smtplib
import logging
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from app.config import get_settings

logger = logging.getLogger(__name__)


def send_admin_notification(subject: str, body: str):
    """Envia un correo al administrador si SMTP esta configurado"""
    settings = get_settings()
    if not settings.admin_email or not settings.smtp_user or not settings.smtp_password:
        logger.info(f"Notificacion omitida (SMTP no configurado): {subject} - {body}")
        return

    try:
        msg = MIMEMultipart()
        msg["From"] = settings.smtp_user
        msg["To"] = settings.admin_email
        msg["Subject"] = subject
        msg.attach(MIMEText(body, "plain", "utf-8"))

        with smtplib.SMTP(settings.smtp_host, settings.smtp_port) as server:
            server.starttls()
            server.login(settings.smtp_user, settings.smtp_password)
            server.send_message(msg)

        logger.info(f"Notificacion enviada a {settings.admin_email}: {subject}")
    except Exception as e:
        logger.warning(f"Error al enviar notificacion por correo: {e}")
