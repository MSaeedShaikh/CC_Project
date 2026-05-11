from flask import Flask, render_template
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from flask_login import LoginManager
from config import Config

db = SQLAlchemy()
migrate = Migrate()
login_manager = LoginManager()
login_manager.login_view = 'auth.login'


def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)

    db.init_app(app)
    migrate.init_app(app, db)
    login_manager.init_app(app)

    from app.auth import auth_bp
    from app.urls import urls_bp
    from app.analytics import analytics_bp
    from app.qr import qr_bp

    app.register_blueprint(auth_bp)
    app.register_blueprint(urls_bp)
    app.register_blueprint(analytics_bp)
    app.register_blueprint(qr_bp)

    with app.app_context():
        db.create_all()

    @app.errorhandler(404)
    def not_found(e):
        return render_template('404.html'), 404

    @app.errorhandler(410)
    def gone(e):
        return render_template('410.html'), 410

    return app
