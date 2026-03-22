/**
 * Dashboard JavaScript
 * نظام تتبع الاستثمارات - بوابة الأعضاء
 */

// ─── Auto Refresh ──────────────────────────────────────────────────────────────
const REFRESH_INTERVAL = 5 * 60 * 1000; // 5 minutes

let refreshTimer = setTimeout(() => {
    window.location.reload();
}, REFRESH_INTERVAL);

// Reset timer on user interaction
document.addEventListener('touchstart', resetRefreshTimer);
document.addEventListener('click', resetRefreshTimer);

function resetRefreshTimer() {
    clearTimeout(refreshTimer);
    refreshTimer = setTimeout(() => window.location.reload(), REFRESH_INTERVAL);
}

// ─── Animate Numbers ──────────────────────────────────────────────────────────
function animateNumbers() {
    const elements = document.querySelectorAll('.stat-value, .loan-amount, .zakat-due, .share-value');
    elements.forEach(el => {
        el.style.opacity = '0';
        el.style.transform = 'translateY(8px)';
        el.style.transition = 'opacity 0.4s ease, transform 0.4s ease';

        // Staggered animation
        const delay = Math.random() * 300;
        setTimeout(() => {
            el.style.opacity = '1';
            el.style.transform = 'translateY(0)';
        }, delay);
    });
}

// ─── Pull-to-Refresh ──────────────────────────────────────────────────────────
let startY = 0;
let pulling = false;
let pullIndicator = null;

document.addEventListener('touchstart', (e) => {
    if (window.scrollY === 0) {
        startY = e.touches[0].clientY;
        pulling = true;
    }
}, { passive: true });

document.addEventListener('touchmove', (e) => {
    if (!pulling) return;
    const deltaY = e.touches[0].clientY - startY;
    if (deltaY > 60) {
        if (!pullIndicator) {
            pullIndicator = document.createElement('div');
            pullIndicator.style.cssText = `
                position: fixed; top: 60px; left: 50%; transform: translateX(-50%);
                background: rgba(212, 168, 32, 0.9); color: #0d1b2e;
                padding: 8px 20px; border-radius: 20px; font-size: 13px; font-weight: 700;
                z-index: 1000; font-family: var(--font-arabic);
            `;
            pullIndicator.textContent = 'اسحب للتحديث ↓';
            document.body.appendChild(pullIndicator);
        }
        if (deltaY > 100) {
            pullIndicator.textContent = 'أفلت للتحديث ✓';
        }
    }
}, { passive: true });

document.addEventListener('touchend', (e) => {
    if (!pulling) return;
    pulling = false;
    const deltaY = e.changedTouches[0].clientY - startY;
    if (deltaY > 100) {
        window.location.reload();
    }
    if (pullIndicator) {
        pullIndicator.remove();
        pullIndicator = null;
    }
});

// ─── Payment List Toggle ───────────────────────────────────────────────────────
function initPaymentList() {
    const list = document.querySelector('.payment-list');
    if (!list) return;

    const items = list.querySelectorAll('.payment-item');
    const INITIAL_SHOW = 6;

    if (items.length <= INITIAL_SHOW) return;

    // Hide extra items initially
    items.forEach((item, index) => {
        if (index >= INITIAL_SHOW) {
            item.style.display = 'none';
        }
    });

    // Add show more button
    const btn = document.createElement('button');
    btn.className = 'show-more-btn';
    btn.style.cssText = `
        width: 100%; padding: 10px; background: rgba(255,255,255,0.05);
        border: 1px solid rgba(255,255,255,0.1); border-radius: 8px;
        color: rgba(255,255,255,0.6); font-size: 0.82rem; cursor: pointer;
        font-family: var(--font-arabic); margin-top: 6px;
    `;
    btn.textContent = `عرض ${items.length - INITIAL_SHOW} دفعة إضافية`;

    let expanded = false;
    btn.addEventListener('click', () => {
        expanded = !expanded;
        items.forEach((item, index) => {
            if (index >= INITIAL_SHOW) {
                item.style.display = expanded ? 'flex' : 'none';
            }
        });
        btn.textContent = expanded ? 'إخفاء' : `عرض ${items.length - INITIAL_SHOW} دفعة إضافية`;
    });

    list.parentElement.appendChild(btn);
}

// ─── Copy to Clipboard ────────────────────────────────────────────────────────
function copyToClipboard(text) {
    navigator.clipboard.writeText(text).then(() => {
        showToast('تم النسخ!');
    }).catch(() => {
        // Fallback
        const el = document.createElement('textarea');
        el.value = text;
        document.body.appendChild(el);
        el.select();
        document.execCommand('copy');
        document.body.removeChild(el);
        showToast('تم النسخ!');
    });
}

// ─── Toast Notification ───────────────────────────────────────────────────────
function showToast(message, type = 'success') {
    const toast = document.createElement('div');
    toast.style.cssText = `
        position: fixed; bottom: 20px; left: 50%; transform: translateX(-50%);
        background: ${type === 'success' ? 'rgba(34,197,94,0.9)' : 'rgba(239,68,68,0.9)'};
        color: white; padding: 10px 24px; border-radius: 20px;
        font-size: 0.9rem; font-weight: 600; z-index: 9999;
        font-family: var(--font-arabic);
        animation: fadeIn 0.3s ease;
    `;
    toast.textContent = message;
    document.body.appendChild(toast);
    setTimeout(() => toast.remove(), 2500);
}

// ─── Format Numbers ───────────────────────────────────────────────────────────
function formatNumber(num) {
    if (num === null || num === undefined) return '0';
    return new Intl.NumberFormat('ar-SA', {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2
    }).format(num);
}

// ─── Smooth Scroll ────────────────────────────────────────────────────────────
document.querySelectorAll('a[href^="#"]').forEach(link => {
    link.addEventListener('click', (e) => {
        e.preventDefault();
        const target = document.querySelector(link.getAttribute('href'));
        if (target) {
            target.scrollIntoView({ behavior: 'smooth' });
        }
    });
});

// ─── Init ──────────────────────────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
    animateNumbers();
    initPaymentList();

    // Add timestamp to footer
    const footer = document.querySelector('.app-footer p');
    if (footer && footer.textContent.includes('{{ now }}')) {
        footer.textContent = footer.textContent.replace(
            '{{ now }}',
            new Date().toLocaleString('ar-SA')
        );
    }

    // Animate ring charts
    const rings = document.querySelectorAll('.ring-fill, .ring-fill-green');
    rings.forEach(ring => {
        const target = ring.style.strokeDasharray;
        ring.style.strokeDasharray = '0 251';
        setTimeout(() => {
            ring.style.transition = 'stroke-dasharray 1s ease';
            ring.style.strokeDasharray = target;
        }, 300);
    });
});

// Add CSS animation
const style = document.createElement('style');
style.textContent = `
    @keyframes fadeIn { from { opacity: 0; transform: translateX(-50%) translateY(10px); } to { opacity: 1; transform: translateX(-50%) translateY(0); } }
`;
document.head.appendChild(style);
