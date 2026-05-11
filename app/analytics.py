from datetime import datetime, timedelta, timezone
from flask import Blueprint, render_template, jsonify
from flask_login import login_required, current_user
from sqlalchemy import func
from app import db
from app.models import URL, Click

analytics_bp = Blueprint('analytics', __name__)


@analytics_bp.route('/dashboard')
@login_required
def dashboard():
    urls = URL.query.filter_by(user_id=current_user.id, is_active=True)\
                    .order_by(URL.created_at.desc()).all()
    return render_template('dashboard.html', urls=urls)


@analytics_bp.route('/api/stats/<code>')
@login_required
def stats(code):
    url_entry = URL.query.filter(
        ((URL.short_code == code) | (URL.custom_slug == code)),
        URL.user_id == current_user.id
    ).first_or_404()

    # clicks per day for last 7 days
    seven_days_ago = datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(days=7)
    daily = db.session.query(
        func.date(Click.timestamp).label('day'),
        func.count(Click.id).label('count')
    ).filter(
        Click.url_id == url_entry.id,
        Click.timestamp >= seven_days_ago
    ).group_by(func.date(Click.timestamp)).all()

    # top referrers
    referrers = db.session.query(
        Click.referrer,
        func.count(Click.id).label('count')
    ).filter(
        Click.url_id == url_entry.id,
        Click.referrer.isnot(None)
    ).group_by(Click.referrer).order_by(func.count(Click.id).desc()).limit(5).all()

    return jsonify({
        'short_code': url_entry.short_code,
        'total_clicks': url_entry.total_clicks,
        'daily_clicks': [{'day': str(r.day), 'count': r.count} for r in daily],
        'top_referrers': [{'referrer': r.referrer, 'count': r.count} for r in referrers],
    })
