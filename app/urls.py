import re
from datetime import datetime, timedelta, timezone
from flask import Blueprint, request, redirect, abort, jsonify, render_template, flash, current_app, url_for
from flask_login import current_user, login_required
from app import db
from app.models import URL, Click

RESERVED_SLUGS = {'shorten', 'login', 'logout', 'register', 'dashboard',
                  'health', 'api', 'qr', 'static'}

urls_bp = Blueprint('urls', __name__)


@urls_bp.route('/')
def index():
    if not current_user.is_authenticated:
        return redirect(url_for('auth.login'))
    return render_template('index.html')


@urls_bp.route('/health')
def health():
    return jsonify({'status': 'ok'}), 200


@urls_bp.route('/shorten', methods=['POST'])
@login_required
def shorten():
    original_url = request.form.get('url', '').strip()
    custom_slug = request.form.get('custom_slug', '').strip() or None
    expires_str = request.form.get('expires_at', '').strip() or None

    if not original_url:
        flash('URL is required.', 'error')
        return redirect('/')

    if not original_url.startswith(('http://', 'https://')):
        original_url = 'https://' + original_url

    # Validate custom slug
    if custom_slug:
        if not re.match(r'^[a-zA-Z0-9\-]{3,50}$', custom_slug):
            flash('Custom slug: 3-50 chars, letters/numbers/hyphens only.', 'error')
            return redirect('/')
        if custom_slug.lower() in RESERVED_SLUGS:
            flash(f'"{custom_slug}" is reserved. Choose a different slug.', 'error')
            return redirect('/')
        # Check collision with existing custom slugs AND short codes
        if (URL.query.filter_by(custom_slug=custom_slug).first() or
                URL.query.filter_by(short_code=custom_slug).first()):
            flash('Custom slug already taken.', 'error')
            return redirect('/')

    expires_at = None
    if expires_str:
        try:
            local_dt = datetime.strptime(expires_str, '%Y-%m-%dT%H:%M')
            tz_offset = request.form.get('tz_offset', '0').strip()
            # Browser's getTimezoneOffset(): minutes to ADD to local time to get UTC
            # e.g. PKT (UTC+5) = -300, EST (UTC-5) = +300
            offset_minutes = int(tz_offset) if tz_offset.lstrip('-').isdigit() else 0
            expires_at = local_dt + timedelta(minutes=offset_minutes)
        except ValueError:
            flash('Invalid expiry date format.', 'error')
            return redirect('/')

    short_code = URL.generate_short_code()
    url_entry = URL(
        user_id=current_user.id,
        original_url=original_url,
        short_code=short_code,
        custom_slug=custom_slug,
        expires_at=expires_at,
    )
    db.session.add(url_entry)
    db.session.commit()

    base = current_app.config['BASE_URL']
    short_url = f"{base}/{custom_slug or short_code}"
    return render_template('index.html', short_url=short_url, short_code=custom_slug or short_code)


@urls_bp.route('/<code>')
def redirect_url(code):
    url_entry = URL.query.filter(
        (URL.short_code == code) | (URL.custom_slug == code)
    ).first_or_404()

    if not url_entry.is_active:
        abort(404)

    if url_entry.is_expired:
        abort(410)

    click = Click(
        url_id=url_entry.id,
        ip_address=request.remote_addr,
        user_agent=request.headers.get('User-Agent'),
        referrer=request.referrer,
    )
    db.session.add(click)
    db.session.commit()

    return render_template('redirect.html', destination=url_entry.original_url)


@urls_bp.route('/api/urls/<int:url_id>', methods=['DELETE'])
@login_required
def delete_url(url_id):
    url_entry = URL.query.filter_by(id=url_id, user_id=current_user.id).first_or_404()
    url_entry.is_active = False
    db.session.commit()
    return jsonify({'message': 'Deleted'}), 200
