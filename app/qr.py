import io
import qrcode
from flask import Blueprint, send_file, abort, current_app
from app.models import URL

qr_bp = Blueprint('qr', __name__)


@qr_bp.route('/qr/<code>')
def generate_qr(code):
    url_entry = URL.query.filter(
        (URL.short_code == code) | (URL.custom_slug == code)
    ).first_or_404()

    if not url_entry.is_active:
        abort(404)

    base = current_app.config['BASE_URL']
    short_url = f"{base}/{url_entry.custom_slug or url_entry.short_code}"

    img = qrcode.make(short_url)
    buf = io.BytesIO()
    img.save(buf, format='PNG')
    buf.seek(0)

    return send_file(buf, mimetype='image/png',
                     download_name=f"{code}.png", as_attachment=False)
