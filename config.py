import os
import sys
from dotenv import load_dotenv

load_dotenv()

def _build_database_url():
    explicit = os.environ.get('DATABASE_URL')
    if explicit:
        return explicit
    project = os.environ.get('GCP_PROJECT_ID')
    region  = os.environ.get('GCP_REGION', 'us-central1')
    db_name = os.environ.get('DB_NAME', 'urlshortener')
    db_user = os.environ.get('DB_USER', 'urluser')
    db_pass = os.environ.get('DB_PASS', '')
    if project:
        socket = f"/cloudsql/{project}:{region}:url-shortener-db"
        return f"postgresql://{db_user}:{db_pass}@/{db_name}?host={socket}"
    return 'sqlite:///urlshortener.db'

_SECRET_KEY = os.environ.get('SECRET_KEY', 'dev-secret-change-in-prod')
_IS_PROD = os.environ.get('FLASK_ENV') == 'production'
if _IS_PROD and _SECRET_KEY == 'dev-secret-change-in-prod':
    sys.exit('ERROR: SECRET_KEY must be set in production. Refusing to start.')

class Config:
    SECRET_KEY = _SECRET_KEY
    SQLALCHEMY_DATABASE_URI = _build_database_url()
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    BASE_URL = os.environ.get('BASE_URL', 'http://localhost:5000')
