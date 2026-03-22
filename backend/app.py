"""
نظام تتبع الاستثمارات والزكاة - بوابة الأعضاء
Member Portal Backend - Flask Application
"""

import os
import sqlite3
import json
from datetime import datetime, timedelta
from functools import wraps
from flask import Flask, request, jsonify, render_template, session, redirect, url_for, g
from flask_cors import CORS

app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', 'invest-tracker-secret-2024')
CORS(app, origins=['*'])

# ─── Database Path ──────────────────────────────────────────────────────────────
DB_PATH = os.environ.get(
    'DB_PATH',
    os.path.expanduser('~/Library/Containers/com.investtracker.app/Data/Documents/invest_tracker.sqlite')
)
# Development fallback
if not os.path.exists(DB_PATH):
    DB_PATH = os.path.join(os.path.dirname(__file__), 'invest_tracker.sqlite')


def get_db():
    """Get database connection for current request."""
    if 'db' not in g:
        if not os.path.exists(DB_PATH):
            init_demo_db()
        g.db = sqlite3.connect(DB_PATH)
        g.db.row_factory = sqlite3.Row
        g.db.execute("PRAGMA foreign_keys = ON")
    return g.db


@app.teardown_appcontext
def close_db(error):
    db = g.pop('db', None)
    if db is not None:
        db.close()


def query_db(sql, args=(), one=False):
    """Execute query and return results."""
    cur = get_db().execute(sql, args)
    rv = cur.fetchall()
    cur.close()
    return (rv[0] if rv else None) if one else rv


def execute_db(sql, args=()):
    """Execute write query."""
    db = get_db()
    db.execute(sql, args)
    db.commit()


# ─── Auth ────────────────────────────────────────────────────────────────────────
def member_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if 'member_id' not in session:
            if request.is_json:
                return jsonify({'error': 'غير مصرح', 'code': 401}), 401
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated


# ─── Routes ─────────────────────────────────────────────────────────────────────

@app.route('/')
def index():
    if 'member_id' in session:
        return redirect(url_for('dashboard'))
    return redirect(url_for('login'))


@app.route('/login', methods=['GET', 'POST'])
def login():
    error = None
    if request.method == 'POST':
        access_code = request.form.get('access_code', '').strip()
        if not access_code:
            error = 'الرجاء إدخال رمز الوصول'
        else:
            member = query_db(
                """SELECT fm.*, f.name as fund_name, f.unit_price, f.id as fund_id
                   FROM fund_members fm
                   INNER JOIN funds f ON f.id = fm.fund_id
                   WHERE fm.web_access_code = ? AND fm.web_access_enabled = 1 AND fm.is_active = 1""",
                [access_code], one=True
            )
            if member:
                session['member_id'] = member['id']
                session['member_name'] = member['name']
                session['fund_id'] = member['fund_id']
                session['fund_name'] = member['fund_name']
                return redirect(url_for('dashboard'))
            else:
                error = 'رمز الوصول غير صحيح أو غير مفعّل'

    return render_template('login.html', error=error)


@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))


@app.route('/dashboard')
@member_required
def dashboard():
    member_id = session['member_id']
    fund_id = session['fund_id']

    member = query_db(
        """SELECT fm.*, f.name as fund_name, f.unit_price, f.payment_day_of_month
           FROM fund_members fm
           INNER JOIN funds f ON f.id = fm.fund_id
           WHERE fm.id = ?""",
        [member_id], one=True
    )

    fund_summary = get_fund_summary(fund_id)
    payment_history = get_member_payment_history(member_id, fund_id)
    loan_info = get_member_loan_info(member_id)
    zakat_info = get_member_zakat_info(member_id, fund_id)

    return render_template(
        'dashboard.html',
        member=dict(member),
        fund_summary=fund_summary,
        payment_history=payment_history,
        loan_info=loan_info,
        zakat_info=zakat_info
    )


# ─── API Endpoints ───────────────────────────────────────────────────────────────

@app.route('/api/member/info')
@member_required
def api_member_info():
    member_id = session['member_id']
    fund_id = session['fund_id']

    member = query_db(
        """SELECT fm.id, fm.name, fm.units, fm.join_date, fm.phone,
                  f.name as fund_name, f.unit_price, f.payment_day_of_month,
                  f.id as fund_id
           FROM fund_members fm
           INNER JOIN funds f ON f.id = fm.fund_id
           WHERE fm.id = ?""",
        [member_id], one=True
    )

    if not member:
        return jsonify({'error': 'العضو غير موجود'}), 404

    fund_summary = get_fund_summary(fund_id)
    total_units = query_db(
        "SELECT SUM(units) as total FROM fund_members WHERE fund_id = ? AND is_active = 1",
        [fund_id], one=True
    )
    total_u = total_units['total'] or 1
    member_units = member['units']
    share_pct = (member_units / total_u) * 100

    return jsonify({
        'member': {
            'id': member['id'],
            'name': member['name'],
            'units': member_units,
            'join_date': member['join_date'],
            'fund_name': member['fund_name'],
            'monthly_contribution': float(member['unit_price']) * member_units,
        },
        'fund': fund_summary,
        'share': {
            'percentage': round(share_pct, 2),
            'value': round(fund_summary.get('total_value', 0) * share_pct / 100, 2),
            'return': round(fund_summary.get('total_return', 0) * share_pct / 100, 2),
        }
    })


@app.route('/api/member/payments')
@member_required
def api_member_payments():
    member_id = session['member_id']
    fund_id = session['fund_id']

    payments = query_db(
        """SELECT * FROM fund_payments
           WHERE member_id = ? AND fund_id = ?
           ORDER BY due_date DESC
           LIMIT 24""",
        [member_id, fund_id]
    )

    return jsonify({
        'payments': [dict(p) for p in payments]
    })


@app.route('/api/member/loan')
@member_required
def api_member_loan():
    member_id = session['member_id']
    loan_info = get_member_loan_info(member_id)
    return jsonify(loan_info)


@app.route('/api/member/zakat')
@member_required
def api_member_zakat():
    member_id = session['member_id']
    fund_id = session['fund_id']
    zakat_info = get_member_zakat_info(member_id, fund_id)
    return jsonify(zakat_info)


@app.route('/api/fund/performance')
@member_required
def api_fund_performance():
    fund_id = session['fund_id']
    summary = get_fund_summary(fund_id)
    return jsonify(summary)


# ─── Helper Functions ────────────────────────────────────────────────────────────

def get_fund_summary(fund_id):
    """Calculate fund summary from DB."""
    fund = query_db("SELECT * FROM funds WHERE id = ?", [fund_id], one=True)
    if not fund:
        return {}

    members = query_db(
        "SELECT SUM(units) as total_units, COUNT(*) as member_count FROM fund_members WHERE fund_id = ? AND is_active = 1",
        [fund_id], one=True
    )

    # Get investments value
    holdings = query_db(
        """SELECT h.shares_remaining, p.price, a.currency
           FROM holdings h
           INNER JOIN assets a ON a.id = h.asset_id
           LEFT JOIN price_cache p ON p.symbol = a.symbol
           WHERE h.fund_id = ? AND h.shares_remaining > 0""",
        [fund_id]
    )

    # Get exchange rate
    fx_row = query_db(
        "SELECT rate FROM exchange_rates WHERE id = 'USD_SAR' ORDER BY timestamp DESC LIMIT 1",
        one=True
    )
    usd_sar = float(fx_row['rate']) if fx_row else 3.75

    investments_value = 0.0
    for h in holdings:
        price = float(h['price'] or 0)
        shares = float(h['shares_remaining'])
        value = price * shares
        if h['currency'] == 'USD':
            value *= usd_sar
        investments_value += value

    cash_balance = float(fund['cash_balance'] or 0)
    total_value = investments_value + cash_balance

    # Total invested (all contributions received)
    contributions = query_db(
        """SELECT COALESCE(SUM(paid_amount), 0) as total
           FROM fund_payments WHERE fund_id = ? AND status = 'PAID'""",
        [fund_id], one=True
    )
    total_invested = float(contributions['total'] or 0)
    total_return = total_value - total_invested

    total_units = int(members['total_units'] or 0)
    nav_per_unit = total_value / total_units if total_units > 0 else 0

    return {
        'fund_id': fund_id,
        'fund_name': fund['name'],
        'total_value': round(total_value, 2),
        'total_invested': round(total_invested, 2),
        'total_return': round(total_return, 2),
        'return_pct': round((total_return / total_invested * 100) if total_invested > 0 else 0, 2),
        'cash_balance': round(cash_balance, 2),
        'nav_per_unit': round(nav_per_unit, 2),
        'total_units': total_units,
        'member_count': int(members['member_count'] or 0),
        'unit_price': float(fund['unit_price']),
        'payment_day': fund['payment_day_of_month'],
    }


def get_member_payment_history(member_id, fund_id, limit=24):
    """Get member's payment history."""
    payments = query_db(
        """SELECT * FROM fund_payments
           WHERE member_id = ? AND fund_id = ?
           ORDER BY due_date DESC LIMIT ?""",
        [member_id, fund_id, limit]
    )

    total_paid = sum(float(p['paid_amount'] or 0) for p in payments if p['status'] == 'PAID')
    late_count = sum(1 for p in payments if p['status'] == 'LATE')

    return {
        'payments': [dict(p) for p in payments],
        'total_paid': round(total_paid, 2),
        'late_count': late_count,
        'payment_rate': round(
            (len([p for p in payments if p['status'] == 'PAID']) / max(len(payments), 1)) * 100, 1
        )
    }


def get_member_loan_info(member_id):
    """Get member's active loan info."""
    loan = query_db(
        "SELECT * FROM loans WHERE member_id = ? AND status = 'ACTIVE' LIMIT 1",
        [member_id], one=True
    )

    if not loan:
        return {'has_loan': False}

    installments = query_db(
        """SELECT * FROM loan_installments WHERE loan_id = ?
           ORDER BY installment_number ASC""",
        [loan['id']]
    )

    paid_installments = [i for i in installments if i['status'] == 'PAID']
    upcoming = [i for i in installments if i['status'] not in ('PAID',)]
    overdue = [i for i in installments if i['status'] == 'LATE']

    total_paid = sum(float(i['paid_amount'] or 0) for i in paid_installments)
    remaining = float(loan['principal_amount']) - total_paid

    next_payment = None
    if upcoming:
        next_payment = dict(upcoming[0])

    return {
        'has_loan': True,
        'loan': {
            'principal': float(loan['principal_amount']),
            'monthly_installment': float(loan['monthly_installment']),
            'disbursement_date': loan['disbursement_date'],
            'status': loan['status'],
        },
        'total_paid': round(total_paid, 2),
        'remaining': round(remaining, 2),
        'completion_pct': round((total_paid / float(loan['principal_amount'])) * 100, 1),
        'installments_paid': len(paid_installments),
        'installments_total': 12,
        'overdue_count': len(overdue),
        'next_payment': next_payment,
        'installments': [dict(i) for i in installments]
    }


def get_member_zakat_info(member_id, fund_id):
    """Get member's zakat share for the fund."""
    latest_calc = query_db(
        """SELECT zc.*, zms.zakat_base, zms.zakat_due, zms.is_paid
           FROM zakat_calculations zc
           INNER JOIN zakat_member_shares zms ON zms.zakat_calculation_id = zc.id
           WHERE zc.fund_id = ? AND zms.member_id = ?
           ORDER BY zc.calculation_date DESC LIMIT 1""",
        [fund_id, member_id], one=True
    )

    if not latest_calc:
        return {'has_zakat': False}

    return {
        'has_zakat': True,
        'calculation_date': latest_calc['calculation_date'],
        'zakat_base': float(latest_calc['zakat_base'] or 0),
        'zakat_due': float(latest_calc['zakat_due'] or 0),
        'is_paid': bool(latest_calc['is_paid']),
        'total_fund_base': float(latest_calc['total_zakat_base'] or 0),
    }


# ─── Demo DB Init ─────────────────────────────────────────────────────────────────

def init_demo_db():
    """Initialize a demo database if none exists."""
    import uuid
    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA journal_mode=WAL")

    # Create tables
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS funds (
            id TEXT PRIMARY KEY, name TEXT, currency TEXT DEFAULT 'SAR',
            unit_price REAL, payment_day_of_month INTEGER DEFAULT 1,
            start_date TEXT, is_active INTEGER DEFAULT 1, cash_balance REAL DEFAULT 0,
            created_at TEXT
        );
        CREATE TABLE IF NOT EXISTS fund_members (
            id TEXT PRIMARY KEY, fund_id TEXT, name TEXT, phone TEXT, email TEXT,
            units INTEGER DEFAULT 1, join_date TEXT, is_active INTEGER DEFAULT 1,
            web_access_code TEXT, web_access_enabled INTEGER DEFAULT 0
        );
        CREATE TABLE IF NOT EXISTS fund_payments (
            id TEXT PRIMARY KEY, fund_id TEXT, member_id TEXT, member_name TEXT,
            due_date TEXT, due_amount REAL, paid_amount REAL DEFAULT 0,
            payment_date TEXT, status TEXT DEFAULT 'PENDING', notes TEXT
        );
        CREATE TABLE IF NOT EXISTS loans (
            id TEXT PRIMARY KEY, fund_id TEXT, member_id TEXT, member_name TEXT,
            principal_amount REAL, monthly_installment REAL,
            disbursement_date TEXT, first_payment_date TEXT, last_payment_date TEXT,
            total_months INTEGER DEFAULT 12, status TEXT DEFAULT 'ACTIVE'
        );
        CREATE TABLE IF NOT EXISTS loan_installments (
            id TEXT PRIMARY KEY, loan_id TEXT, installment_number INTEGER,
            due_date TEXT, due_amount REAL, paid_amount REAL DEFAULT 0,
            paid_date TEXT, status TEXT DEFAULT 'UPCOMING'
        );
        CREATE TABLE IF NOT EXISTS holdings (
            id TEXT PRIMARY KEY, asset_id TEXT, portfolio_id TEXT, fund_id TEXT,
            purchase_date TEXT, shares_original REAL, shares_remaining REAL,
            purchase_price REAL, purchase_currency TEXT DEFAULT 'SAR',
            exchange_rate_at_purchase REAL, fees REAL DEFAULT 0, taxes REAL DEFAULT 0
        );
        CREATE TABLE IF NOT EXISTS assets (
            id TEXT PRIMARY KEY, symbol TEXT, name TEXT, name_ar TEXT,
            type TEXT, currency TEXT, current_price REAL DEFAULT 0,
            last_price_update TEXT, sector TEXT, market TEXT, is_active INTEGER DEFAULT 1,
            created_at TEXT
        );
        CREATE TABLE IF NOT EXISTS price_cache (
            symbol TEXT PRIMARY KEY, price REAL, currency TEXT,
            timestamp TEXT, source TEXT, previous_close REAL,
            daily_change REAL, daily_change_pct REAL
        );
        CREATE TABLE IF NOT EXISTS exchange_rates (
            id TEXT PRIMARY KEY, from_currency TEXT, to_currency TEXT,
            rate REAL, timestamp TEXT, source TEXT
        );
        CREATE TABLE IF NOT EXISTS zakat_calculations (
            id TEXT PRIMARY KEY, portfolio_id TEXT, fund_id TEXT,
            calculation_date TEXT, hijri_year INTEGER, hijri_month INTEGER,
            gold_price_24k REAL, nisab_amount_sar REAL,
            holdings_value REAL, cash_value REAL, dividends_value REAL,
            total_zakat_base REAL, is_nisab_met INTEGER, zakat_due REAL,
            status TEXT DEFAULT 'CALCULATED', paid_at TEXT, paid_amount REAL
        );
        CREATE TABLE IF NOT EXISTS zakat_member_shares (
            id TEXT PRIMARY KEY, zakat_calculation_id TEXT, member_id TEXT,
            member_name TEXT, units INTEGER, total_units INTEGER,
            zakat_base REAL, zakat_due REAL, is_paid INTEGER DEFAULT 0
        );
    """)

    # Demo data
    now = datetime.utcnow().isoformat()
    fund_id = str(uuid.uuid4())

    conn.execute("""INSERT OR IGNORE INTO funds VALUES (?, ?, 'SAR', 1000, 1, ?, 1, 50000, ?)""",
                 [fund_id, 'صندوق العائلة الاستثماري', '2023-01-01T00:00:00', now])

    members_data = [
        ('عبدالله العمري', '0501234567', 2, '123456'),
        ('محمد القحطاني', '0507654321', 1, '234567'),
        ('سارة الزهراني', '0509876543', 3, '345678'),
    ]

    member_ids = []
    for name, phone, units, code in members_data:
        mid = str(uuid.uuid4())
        member_ids.append(mid)
        conn.execute("""INSERT OR IGNORE INTO fund_members
            VALUES (?, ?, ?, ?, NULL, ?, ?, 1, ?, 1)""",
            [mid, fund_id, name, phone, units, now, code])

    # Demo payments (last 3 months)
    for i, mid in enumerate(member_ids):
        _, phone, units, _ = members_data[i]
        name = members_data[i][0]
        for month in range(3, 0, -1):
            due_date = (datetime.utcnow() - timedelta(days=30*month)).strftime('%Y-%m-%d')
            payment_id = str(uuid.uuid4())
            status = 'PAID' if month > 1 else ('PAID' if i < 2 else 'PENDING')
            paid_amount = 1000 * units if status == 'PAID' else 0
            conn.execute("""INSERT OR IGNORE INTO fund_payments VALUES
                (?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)""",
                [payment_id, fund_id, mid, name, due_date,
                 1000 * units, paid_amount, due_date if status == 'PAID' else None, status])

    # Exchange rate
    conn.execute("INSERT OR REPLACE INTO exchange_rates VALUES ('USD_SAR', 'USD', 'SAR', 3.75, ?, 'fixed')",
                 [now])

    conn.commit()
    conn.close()
    print(f"Demo database created at: {DB_PATH}")


# ─── Run ─────────────────────────────────────────────────────────────────────────

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    debug = os.environ.get('DEBUG', 'false').lower() == 'true'
    print(f"Starting member portal on port {port}")
    print(f"Database: {DB_PATH}")
    app.run(host='0.0.0.0', port=port, debug=debug)
