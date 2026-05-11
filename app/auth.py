import bcrypt
from flask import Blueprint, render_template, redirect, url_for, request, flash
from flask_login import login_user, logout_user, login_required, current_user
from app import db
from app.models import User

auth_bp = Blueprint('auth', __name__)


@auth_bp.route('/register', methods=['GET', 'POST'])
def register():
    if current_user.is_authenticated:
        return redirect(url_for('analytics.dashboard'))

    if request.method == 'POST':
        username = request.form.get('username', '').strip()
        email = request.form.get('email', '').strip()
        password = request.form.get('password', '')

        if not username or not email or not password:
            flash('All fields required.', 'error')
            return render_template('register.html')

        if User.query.filter_by(username=username).first():
            flash('Username already taken.', 'error')
            return render_template('register.html')

        if User.query.filter_by(email=email).first():
            flash('Email already registered.', 'error')
            return render_template('register.html')

        hashed = bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()
        user = User(username=username, email=email, password_hash=hashed)
        db.session.add(user)
        db.session.commit()

        login_user(user)
        return redirect(url_for('analytics.dashboard'))

    return render_template('register.html')


@auth_bp.route('/login', methods=['GET', 'POST'])
def login():
    if current_user.is_authenticated:
        return redirect(url_for('analytics.dashboard'))

    if request.method == 'POST':
        email = request.form.get('email', '').strip()
        password = request.form.get('password', '')

        user = User.query.filter_by(email=email).first()
        if not user or not bcrypt.checkpw(password.encode(), user.password_hash.encode()):
            flash('Invalid email or password.', 'error')
            return render_template('login.html')

        login_user(user)
        next_page = request.args.get('next')
        if next_page and (next_page.startswith('/') and not next_page.startswith('//')):
            return redirect(next_page)
        return redirect(url_for('analytics.dashboard'))

    return render_template('login.html')


@auth_bp.route('/logout')
@login_required
def logout():
    logout_user()
    return redirect(url_for('urls.index'))
