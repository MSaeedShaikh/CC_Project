import random
import string
from datetime import datetime, timezone
from flask_login import UserMixin
from sqlalchemy import func
from app import db, login_manager


@login_manager.user_loader
def load_user(user_id):
    from app import db
    return db.session.get(User, int(user_id))


class User(UserMixin, db.Model):
    __tablename__ = 'users'

    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(50), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))

    urls = db.relationship('URL', backref='owner', lazy=True)


class URL(db.Model):
    __tablename__ = 'urls'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=True)
    original_url = db.Column(db.Text, nullable=False)
    short_code = db.Column(db.String(10), unique=True, nullable=False, index=True)
    custom_slug = db.Column(db.String(50), unique=True, nullable=True)
    expires_at = db.Column(db.DateTime, nullable=True)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))
    is_active = db.Column(db.Boolean, default=True)

    clicks = db.relationship('Click', backref='url', lazy=True)

    @staticmethod
    def generate_short_code(length=6):
        chars = string.ascii_letters + string.digits
        while True:
            code = ''.join(random.choices(chars, k=length))
            if (not URL.query.filter_by(short_code=code).first() and
                    not URL.query.filter_by(custom_slug=code).first()):
                return code

    @property
    def is_expired(self):
        return self.expires_at is not None and self.expires_at < datetime.now(timezone.utc).replace(tzinfo=None)

    @property
    def hours_until_expiry(self):
        if not self.expires_at or self.is_expired:
            return None
        delta = self.expires_at - datetime.now(timezone.utc).replace(tzinfo=None)
        return delta.total_seconds() / 3600

    @property
    def total_clicks(self):
        return db.session.query(func.count(Click.id)).filter(Click.url_id == self.id).scalar() or 0


class Click(db.Model):
    __tablename__ = 'clicks'

    id = db.Column(db.Integer, primary_key=True)
    url_id = db.Column(db.Integer, db.ForeignKey('urls.id'), nullable=False)
    timestamp = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))
    ip_address = db.Column(db.String(45))
    user_agent = db.Column(db.Text)
    referrer = db.Column(db.Text)
