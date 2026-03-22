/* ============================================
   InvestTracker - Main Application Logic
   ============================================ */

/* ---- State ---- */
let currentView = 'dashboard';
let currentFundId = null;
let portfolioFilter = 'all';
let portfolioChart = null;
let assetsChart = null;

const ASSET_TYPES = {
  SA_STOCK: 'سهم سعودي',
  US_STOCK: 'سهم أمريكي',
  FUND: 'صندوق',
  ETF: 'ETF',
  GOLD: 'ذهب',
  CASH: 'نقد',
};

const ASSET_COLORS = {
  SA_STOCK: '#22c55e',
  US_STOCK: '#3b82f6',
  FUND: '#a855f7',
  ETF: '#06b6d4',
  GOLD: '#f59e0b',
  CASH: '#94a3b8',
};

/* ---- Startup ---- */
document.addEventListener('DOMContentLoaded', () => {
  DB.seedDemoData();
  setupNavigation();
  setDefaultDates();
  renderAll();
});

function renderAll() {
  renderDashboard();
  renderPortfolio();
  renderFundsList();
  renderZakat();
  renderLoans();
  renderReports();
}

/* ---- Navigation ---- */
function setupNavigation() {
  // Sidebar
  document.querySelectorAll('.nav-link').forEach(link => {
    link.addEventListener('click', e => {
      e.preventDefault();
      navigateTo(link.dataset.view);
    });
  });
  // Bottom nav
  document.querySelectorAll('.bottom-nav-link').forEach(link => {
    link.addEventListener('click', e => {
      e.preventDefault();
      navigateTo(link.dataset.view);
    });
  });
  // Filter tabs
  document.querySelectorAll('.filter-tab').forEach(tab => {
    tab.addEventListener('click', () => {
      document.querySelectorAll('.filter-tab').forEach(t => t.classList.remove('active'));
      tab.classList.add('active');
      portfolioFilter = tab.dataset.filter;
      renderAssetsTable();
    });
  });
}

function navigateTo(view) {
  currentView = view;
  document.querySelectorAll('.view').forEach(v => v.classList.remove('active'));
  document.getElementById(view + '-view').classList.add('active');
  document.querySelectorAll('.nav-link, .bottom-nav-link').forEach(l => {
    l.classList.toggle('active', l.dataset.view === view);
  });
  // Hide fund detail when leaving funds view
  if (view !== 'funds') closeFundDetail();
}

function setDefaultDates() {
  const today = new Date().toISOString().split('T')[0];
  const thisMonth = today.slice(0, 7);
  document.querySelectorAll('input[type="date"]').forEach(el => {
    if (!el.value) el.value = today;
  });
  document.querySelectorAll('input[type="month"]').forEach(el => {
    if (!el.value) el.value = thisMonth;
  });
}

/* ============ DASHBOARD ============ */
function renderDashboard() {
  const ps = DB.getPortfolioStats();
  const funds = DB.getFunds();
  const zs = DB.getZakatStats(getGoldPrice());
  const ls = DB.getLoanStats();

  // Stats
  document.getElementById('total-portfolio').textContent = fmt(ps.totalValue);
  const pnlEl = document.getElementById('portfolio-pnl');
  pnlEl.textContent = (ps.pnl >= 0 ? '+' : '') + fmt(ps.pnl) + ' (' + ps.pnlPct.toFixed(1) + '%)';
  pnlEl.style.color = ps.pnl >= 0 ? 'var(--green)' : 'var(--red)';

  const fundTotal = funds.reduce((s, f) => s + (f.totalValue || 0), 0);
  document.getElementById('total-funds').textContent = fmt(fundTotal);
  document.getElementById('total-members').textContent =
    funds.reduce((s, f) => s + f.members.length, 0) + ' أعضاء';

  document.getElementById('total-zakat').textContent = fmt(zs.zakatDue);
  document.getElementById('zakat-status').textContent =
    zs.meetsNisab ? 'تجاوز النصاب' : 'لم يبلغ النصاب';

  document.getElementById('total-loans').textContent = fmt(ls.total);
  document.getElementById('loans-status').textContent =
    ls.overdue > 0 ? ls.overdue + ' قسط متأخر' : 'لا توجد أقساط متأخرة';

  // Portfolio donut chart
  renderPortfolioChart(ps.byType);

  // Funds summary
  const fl = document.getElementById('funds-summary-list');
  if (funds.length === 0) {
    fl.innerHTML = '<div class="empty-state">لا توجد صناديق - أضف صندوقاً جديداً</div>';
  } else {
    fl.innerHTML = funds.map(f => {
      const stats = DB.getFundStats(f);
      return `<div class="summary-item" onclick="openFund('${f.id}')">
        <div>
          <div class="summary-item-name">${f.name}</div>
          <div class="summary-item-sub">${f.members.length} أعضاء · ${stats.totalUnits} وحدة</div>
        </div>
        <div class="summary-item-value">${fmt(stats.totalValue)}</div>
      </div>`;
    }).join('');
  }

  // Recent transactions
  const txs = DB.getTransactions().slice(0, 8);
  const tl = document.getElementById('recent-transactions');
  if (txs.length === 0) {
    tl.innerHTML = '<div class="empty-state">لا توجد معاملات بعد</div>';
  } else {
    tl.innerHTML = txs.map(tx => `
      <div class="tx-item">
        <div class="tx-info">
          <div class="tx-name">${tx.assetName || tx.type}</div>
          <div class="tx-sub">${tx.type === 'BUY' ? 'شراء' : 'بيع'} · ${formatDate(tx.date)}</div>
        </div>
        <div class="tx-amount ${tx.type === 'BUY' ? 'negative' : 'positive'}">${fmt(tx.total)}</div>
      </div>
    `).join('');
  }
}

function renderPortfolioChart(byType) {
  const canvas = document.getElementById('portfolio-chart');
  const ctx = canvas.getContext('2d');

  const labels = Object.keys(byType).map(k => ASSET_TYPES[k] || k);
  const data = Object.values(byType);
  const colors = Object.keys(byType).map(k => ASSET_COLORS[k] || '#94a3b8');

  if (portfolioChart) portfolioChart.destroy();

  if (data.length === 0) {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.fillStyle = '#64748b';
    ctx.font = '14px Arial';
    ctx.textAlign = 'center';
    ctx.fillText('لا توجد بيانات', canvas.width / 2, canvas.height / 2);
    return;
  }

  portfolioChart = new Chart(ctx, {
    type: 'doughnut',
    data: {
      labels,
      datasets: [{
        data,
        backgroundColor: colors,
        borderColor: '#1e293b',
        borderWidth: 2,
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          position: 'bottom',
          labels: { color: '#94a3b8', font: { size: 12 }, padding: 12 }
        },
        tooltip: {
          callbacks: {
            label: ctx => ` ${fmt(ctx.parsed)}`
          }
        }
      }
    }
  });
}

/* ============ PORTFOLIO ============ */
function renderPortfolio() {
  const ps = DB.getPortfolioStats();

  document.getElementById('p-total-value').textContent = fmt(ps.totalValue);
  document.getElementById('p-total-cost').textContent = fmt(ps.totalCost);
  document.getElementById('p-pnl').textContent = (ps.pnl >= 0 ? '+' : '') + fmt(ps.pnl);
  document.getElementById('p-pnl').style.color = ps.pnl >= 0 ? 'var(--green)' : 'var(--red)';
  document.getElementById('p-pnl-pct').textContent = (ps.pnlPct >= 0 ? '+' : '') + ps.pnlPct.toFixed(2) + '%';

  const pnlCard = document.getElementById('p-pnl-card');
  pnlCard.classList.remove('green', 'red');
  pnlCard.style.borderTopColor = ps.pnl >= 0 ? 'var(--green)' : 'var(--red)';

  renderAssetsTable();
}

function renderAssetsTable() {
  const container = document.getElementById('assets-table');
  let assets = DB.getAssets();

  if (portfolioFilter !== 'all') {
    assets = assets.filter(a => a.type === portfolioFilter);
  }

  if (assets.length === 0) {
    container.innerHTML = '<div class="empty-state">لا توجد أصول في هذه الفئة</div>';
    return;
  }

  container.innerHTML = `
    <table>
      <thead>
        <tr>
          <th>الأصل</th>
          <th>النوع</th>
          <th>الكمية</th>
          <th>سعر الشراء</th>
          <th>السعر الحالي</th>
          <th>القيمة</th>
          <th>الربح/الخسارة</th>
          <th>إجراءات</th>
        </tr>
      </thead>
      <tbody>
        ${assets.map(a => {
          const value = a.quantity * a.currentPrice;
          const cost = a.quantity * a.buyPrice;
          const pnl = value - cost;
          const pnlPct = cost > 0 ? (pnl / cost * 100) : 0;
          return `<tr>
            <td>
              <div style="font-weight:600">${a.name}</div>
              ${a.symbol ? `<div style="font-size:0.75rem;color:var(--text2)">${a.symbol}</div>` : ''}
            </td>
            <td><span class="badge badge-blue">${ASSET_TYPES[a.type] || a.type}</span></td>
            <td>${fmtNum(a.quantity)}</td>
            <td>${fmtNum(a.buyPrice)} ر.س</td>
            <td>${fmtNum(a.currentPrice)} ر.س</td>
            <td style="font-weight:600">${fmt(value)}</td>
            <td style="color:${pnl >= 0 ? 'var(--green)' : 'var(--red)'}">
              ${(pnl >= 0 ? '+' : '') + fmt(pnl)}<br>
              <span style="font-size:0.75rem">${(pnlPct >= 0 ? '+' : '') + pnlPct.toFixed(1)}%</span>
            </td>
            <td>
              <button class="action-btn" onclick="openEditAsset('${a.id}')">✏️</button>
              <button class="action-btn delete" onclick="deleteAsset('${a.id}')">🗑️</button>
            </td>
          </tr>`;
        }).join('')}
      </tbody>
    </table>
  `;
}

/* ============ FUNDS ============ */
function renderFundsList() {
  const funds = DB.getFunds();
  const container = document.getElementById('funds-list');

  if (funds.length === 0) {
    container.innerHTML = '<div class="empty-state">لا توجد صناديق - أضف صندوقاً جديداً</div>';
    return;
  }

  container.innerHTML = funds.map(f => {
    const stats = DB.getFundStats(f);
    return `
      <div class="fund-card" onclick="openFund('${f.id}')">
        <div class="fund-card-name">${f.name}</div>
        <div class="fund-card-desc">${f.description || 'صندوق استثماري'}</div>
        <div class="fund-card-stats">
          <div class="fund-stat">
            <span class="label">القيمة الإجمالية</span>
            <span class="value" style="color:var(--green)">${fmt(stats.totalValue)}</span>
          </div>
          <div class="fund-stat">
            <span class="label">صافي الوحدة</span>
            <span class="value">${fmt(stats.nav)}</span>
          </div>
          <div class="fund-stat">
            <span class="label">عدد الوحدات</span>
            <span class="value">${fmtNum(stats.totalUnits)}</span>
          </div>
          <div class="fund-stat">
            <span class="label">الأعضاء</span>
            <span class="value">${stats.membersCount} عضو</span>
          </div>
        </div>
      </div>
    `;
  }).join('');
}

function openFund(id) {
  currentFundId = id;
  const fund = DB.getFund(id);
  if (!fund) return;

  navigateTo('funds');

  document.getElementById('funds-list').classList.add('hidden');
  document.querySelector('.view-header').classList.add('hidden');
  const detail = document.getElementById('fund-detail');
  detail.classList.remove('hidden');

  const stats = DB.getFundStats(fund);
  document.getElementById('fund-detail-name').textContent = fund.name;
  document.getElementById('fd-nav').textContent = fmt(stats.nav);
  document.getElementById('fd-units').textContent = fmtNum(stats.totalUnits);
  document.getElementById('fd-total').textContent = fmt(stats.totalValue);
  document.getElementById('fd-members-count').textContent = stats.membersCount;

  renderFundMembers(fund, stats);
  renderFundPayments(fund);
}

function closeFundDetail() {
  currentFundId = null;
  const detail = document.getElementById('fund-detail');
  if (detail) detail.classList.add('hidden');
  const fl = document.getElementById('funds-list');
  if (fl) fl.classList.remove('hidden');
  const vh = document.querySelector('#funds-view .view-header');
  if (vh) vh.classList.remove('hidden');
}

function renderFundMembers(fund, stats) {
  const container = document.getElementById('fund-members-list');
  if (fund.members.length === 0) {
    container.innerHTML = '<div class="empty-state">لا يوجد أعضاء - أضف عضواً جديداً</div>';
    return;
  }

  container.innerHTML = fund.members.map(m => {
    const memberValue = m.units * stats.nav;
    const paidCount = fund.payments.filter(p => p.memberId === m.id && p.status === 'paid').length;
    return `
      <div class="member-item">
        <div class="member-info">
          <div class="member-name">${m.name}</div>
          <div class="member-meta">انضم: ${formatDate(m.joinDate)} · كود: ${m.accessCode || 'N/A'}</div>
        </div>
        <div class="member-stats">
          <div class="member-stat">
            <span class="label">الوحدات</span>
            <span class="value">${m.units}</span>
          </div>
          <div class="member-stat">
            <span class="label">الحصة</span>
            <span class="value" style="color:var(--green)">${fmt(memberValue)}</span>
          </div>
          <div class="member-stat">
            <span class="label">الدفعات</span>
            <span class="value">${paidCount}</span>
          </div>
        </div>
      </div>
    `;
  }).join('');
}

function renderFundPayments(fund) {
  const container = document.getElementById('fund-payments-list');
  if (fund.payments.length === 0) {
    container.innerHTML = '<div class="empty-state">لا توجد دفعات مسجلة</div>';
    return;
  }

  const statusMap = { paid: ['مدفوع', 'badge-green'], partial: ['جزئي', 'badge-orange'], pending: ['معلق', 'badge-gray'] };
  container.innerHTML = [...fund.payments].reverse().map(p => {
    const [label, cls] = statusMap[p.status] || ['غير محدد', 'badge-gray'];
    return `
      <div class="payment-item">
        <div>
          <div style="font-weight:600">${p.memberName || 'عضو'}</div>
          <div style="font-size:0.8rem;color:var(--text2)">${p.month || ''} ${p.notes ? '· ' + p.notes : ''}</div>
        </div>
        <div style="display:flex;align-items:center;gap:12px">
          <span class="badge ${cls}">${label}</span>
          <span style="font-weight:700;color:var(--green)">${fmt(p.amount)}</span>
        </div>
      </div>
    `;
  }).join('');
}

/* ============ ZAKAT ============ */
function getGoldPrice() {
  return parseFloat(document.getElementById('gold-price')?.value) || 220;
}

function recalcZakat() {
  renderZakat();
}

function renderZakat() {
  const goldPrice = getGoldPrice();
  const zs = DB.getZakatStats(goldPrice);

  document.getElementById('nisab-value').textContent = fmt(zs.nisab) + ' ر.س';
  document.getElementById('z-total-base').textContent = fmt(zs.zakatableBase);
  document.getElementById('z-total-due').textContent = fmt(zs.zakatDue);
  document.getElementById('z-total-paid').textContent = fmt(zs.zakatPaid);
  document.getElementById('z-total-remaining').textContent = fmt(zs.zakatRemaining);

  // Breakdown by asset
  const assets = DB.getAssets();
  const breakdown = document.getElementById('zakat-breakdown');

  if (assets.length === 0) {
    breakdown.innerHTML = '<div class="empty-state">أضف أصولاً لحساب الزكاة</div>';
  } else {
    const nisabMet = zs.meetsNisab;
    breakdown.innerHTML = assets.map(a => {
      const val = a.type === 'GOLD' ? a.quantity * goldPrice : a.quantity * a.currentPrice;
      const zakatAmt = nisabMet ? val * 0.025 : 0;
      return `
        <div class="zakat-item">
          <div>
            <div class="zakat-item-name">${a.name}</div>
            <div class="zakat-item-sub">${ASSET_TYPES[a.type] || a.type} · ${fmt(val)}</div>
          </div>
          <div class="zakat-item-amount">${nisabMet ? fmt(zakatAmt) : 'دون النصاب'}</div>
        </div>
      `;
    }).join('');
  }

  // Zakat payment records
  const records = DB.getZakat();
  const statusMap = { paid: ['مدفوعة', 'badge-green'], calculated: ['محسوبة', 'badge-blue'], partial: ['جزئي', 'badge-orange'], waived: ['مُسقطة', 'badge-gray'] };
  const zpl = document.getElementById('zakat-payments-list');
  if (records.length === 0) {
    zpl.innerHTML = '<div class="empty-state">لا توجد دفعات مسجلة</div>';
  } else {
    zpl.innerHTML = [...records].reverse().map(z => {
      const [label, cls] = statusMap[z.status] || ['غير محدد', 'badge-gray'];
      return `
        <div class="payment-item">
          <div>
            <div style="font-weight:600">زكاة ${z.year || ''}</div>
            <div style="font-size:0.8rem;color:var(--text2)">وعاء: ${fmt(z.base)} · تاريخ الدفع: ${formatDate(z.payDate)}</div>
          </div>
          <div style="display:flex;align-items:center;gap:12px">
            <span class="badge ${cls}">${label}</span>
            <span style="font-weight:700;color:var(--orange)">${fmt(z.amount)}</span>
          </div>
        </div>
      `;
    }).join('');
  }
}

/* ============ LOANS ============ */
function renderLoans() {
  const ls = DB.getLoanStats();
  document.getElementById('l-total').textContent = fmt(ls.total);
  document.getElementById('l-remaining').textContent = fmt(ls.remaining);
  document.getElementById('l-paid').textContent = fmt(ls.paid);
  document.getElementById('l-overdue').textContent = ls.overdue;

  const loans = DB.getLoans();
  const container = document.getElementById('loans-list');
  const today = new Date().toISOString().split('T')[0];

  if (loans.length === 0) {
    container.innerHTML = '<div class="empty-state">لا توجد قروض - أضف قرضاً جديداً</div>';
    return;
  }

  container.innerHTML = loans.map(loan => {
    const paidPct = loan.amount > 0 ? (loan.paidAmount / loan.amount * 100) : 0;
    const paidInstallments = loan.schedule.filter(s => s.paid).length;
    const overdueInstallments = loan.schedule.filter(s => !s.paid && s.dueDate < today).length;
    const statusLabel = loan.status === 'completed' ? 'مكتمل' : overdueInstallments > 0 ? 'متأخر' : 'نشط';
    const statusCls = loan.status === 'completed' ? 'badge-green' : overdueInstallments > 0 ? 'badge-red' : 'badge-blue';

    const nextUnpaid = loan.schedule.find(s => !s.paid);

    return `
      <div class="loan-item">
        <div class="loan-header">
          <div>
            <div class="loan-borrower">${loan.borrower}</div>
            <div style="font-size:0.8rem;color:var(--text2)">${loan.purpose || 'قرض حسن'}</div>
          </div>
          <div style="text-align:left">
            <div class="loan-amount">${fmt(loan.amount)}</div>
            <span class="badge ${statusCls}">${statusLabel}</span>
          </div>
        </div>
        <div class="loan-progress">
          <div class="loan-progress-bar" style="width:${paidPct}%"></div>
        </div>
        <div class="loan-meta">
          <span>مدفوع: ${fmt(loan.paidAmount)} (${paidPct.toFixed(0)}%)</span>
          <span>المتبقي: ${fmt(loan.amount - loan.paidAmount)}</span>
          <span>الأقساط: ${paidInstallments}/${loan.installments}</span>
          ${overdueInstallments > 0 ? `<span style="color:var(--red)">متأخر: ${overdueInstallments} قسط</span>` : ''}
          ${nextUnpaid ? `<span>القسط القادم: ${fmt(nextUnpaid.amount)} · ${formatDate(nextUnpaid.dueDate)}</span>` : ''}
        </div>
        ${loan.status !== 'completed' ? `
          <div class="loan-actions">
            ${nextUnpaid ? `<button class="btn btn-secondary btn-sm" onclick="payInstallment('${loan.id}', ${loan.schedule.indexOf(nextUnpaid)})">✅ دفع القسط القادم</button>` : ''}
          </div>
        ` : ''}
      </div>
    `;
  }).join('');
}

/* ============ REPORTS ============ */
function renderReports() {
  // Assets breakdown chart
  const ps = DB.getPortfolioStats();
  const assetsCanvas = document.getElementById('assets-chart');
  const ctx2 = assetsCanvas.getContext('2d');

  const labels = Object.keys(ps.byType).map(k => ASSET_TYPES[k] || k);
  const data = Object.values(ps.byType);
  const colors = Object.keys(ps.byType).map(k => ASSET_COLORS[k] || '#94a3b8');

  if (assetsChart) assetsChart.destroy();

  if (data.length > 0) {
    assetsChart = new Chart(ctx2, {
      type: 'bar',
      data: {
        labels,
        datasets: [{
          data,
          backgroundColor: colors,
          borderRadius: 6,
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: { callbacks: { label: ctx => ` ${fmt(ctx.parsed.y)}` } }
        },
        scales: {
          x: { ticks: { color: '#94a3b8' }, grid: { color: '#334155' } },
          y: { ticks: { color: '#94a3b8', callback: v => fmt(v) }, grid: { color: '#334155' } }
        }
      }
    });
  }

  // Funds performance
  const funds = DB.getFunds();
  const perfEl = document.getElementById('funds-performance');
  if (funds.length === 0) {
    perfEl.innerHTML = '<div class="empty-state">لا توجد صناديق</div>';
  } else {
    perfEl.innerHTML = funds.map(f => {
      const stats = DB.getFundStats(f);
      const totalPaid = f.payments.filter(p => p.status === 'paid').reduce((s, p) => s + p.amount, 0);
      return `
        <div class="performance-item">
          <div>
            <div style="font-weight:600">${f.name}</div>
            <div style="font-size:0.8rem;color:var(--text2)">${f.members.length} أعضاء · ${stats.totalUnits} وحدة</div>
          </div>
          <div style="text-align:left">
            <div style="font-weight:700;color:var(--green)">${fmt(stats.totalValue)}</div>
            <div style="font-size:0.8rem;color:var(--text2)">مجموع الدفعات: ${fmt(totalPaid)}</div>
          </div>
        </div>
      `;
    }).join('');
  }

  // Zakat annual report
  const zakatRecords = DB.getZakat();
  const zr = document.getElementById('zakat-annual-report');
  if (zakatRecords.length === 0) {
    zr.innerHTML = '<div class="empty-state">لا توجد سجلات زكاة</div>';
  } else {
    const total = zakatRecords.reduce((s, z) => s + (z.amount || 0), 0);
    zr.innerHTML = `
      <div style="margin-bottom:16px">
        <span style="font-size:0.9rem;color:var(--text2)">إجمالي الزكاة المسجلة: </span>
        <strong style="color:var(--orange)">${fmt(total)}</strong>
      </div>
      <table>
        <thead><tr><th>السنة</th><th>وعاء الزكاة</th><th>المبلغ</th><th>الحالة</th><th>التاريخ</th></tr></thead>
        <tbody>
          ${zakatRecords.map(z => {
            const statusMap = { paid: ['مدفوعة', 'badge-green'], calculated: ['محسوبة', 'badge-blue'], partial: ['جزئي', 'badge-orange'], waived: ['مُسقطة', 'badge-gray'] };
            const [label, cls] = statusMap[z.status] || ['N/A', 'badge-gray'];
            return `<tr>
              <td>${z.year || '-'}</td>
              <td>${fmt(z.base)}</td>
              <td style="color:var(--orange);font-weight:600">${fmt(z.amount)}</td>
              <td><span class="badge ${cls}">${label}</span></td>
              <td>${formatDate(z.payDate)}</td>
            </tr>`;
          }).join('')}
        </tbody>
      </table>
    `;
  }
}

/* ============ MODAL HANDLERS ============ */
function showModal(id) {
  document.getElementById(id).classList.remove('hidden');
}

function closeModal(id) {
  document.getElementById(id).classList.add('hidden');
}

// Close modal on overlay click
document.addEventListener('click', e => {
  if (e.target.classList.contains('modal-overlay')) {
    e.target.classList.add('hidden');
  }
});

/* ---- Add Asset ---- */
function submitAddAsset(e) {
  e.preventDefault();
  DB.addAsset({
    name: document.getElementById('asset-name').value.trim(),
    symbol: document.getElementById('asset-symbol').value.trim(),
    type: document.getElementById('asset-type').value,
    quantity: parseFloat(document.getElementById('asset-quantity').value),
    buyPrice: parseFloat(document.getElementById('asset-buy-price').value),
    currentPrice: parseFloat(document.getElementById('asset-current-price').value),
    date: document.getElementById('asset-date').value,
    notes: document.getElementById('asset-notes').value.trim(),
  });
  closeModal('add-asset-modal');
  document.getElementById('add-asset-form').reset();
  setDefaultDates();
  renderAll();
  toast('تمت إضافة الأصل بنجاح', 'success');
}

/* ---- Edit Asset ---- */
function openEditAsset(id) {
  const asset = DB.getAssets().find(a => a.id === id);
  if (!asset) return;
  document.getElementById('edit-asset-id').value = id;
  document.getElementById('edit-asset-name').value = asset.name;
  document.getElementById('edit-asset-price').value = asset.currentPrice;
  document.getElementById('edit-asset-qty').value = asset.quantity;
  document.getElementById('edit-asset-buy').value = asset.buyPrice;
  showModal('edit-asset-modal');
}

function submitEditAsset(e) {
  e.preventDefault();
  const id = document.getElementById('edit-asset-id').value;
  DB.updateAsset(id, {
    name: document.getElementById('edit-asset-name').value.trim(),
    currentPrice: parseFloat(document.getElementById('edit-asset-price').value),
    quantity: parseFloat(document.getElementById('edit-asset-qty').value),
    buyPrice: parseFloat(document.getElementById('edit-asset-buy').value),
  });
  closeModal('edit-asset-modal');
  renderAll();
  toast('تم تعديل الأصل', 'success');
}

function deleteAsset(id) {
  if (!confirm('هل تريد حذف هذا الأصل؟')) return;
  DB.deleteAsset(id);
  renderAll();
  toast('تم الحذف', 'success');
}

/* ---- Add Fund ---- */
function submitAddFund(e) {
  e.preventDefault();
  DB.addFund({
    name: document.getElementById('fund-name').value.trim(),
    description: document.getElementById('fund-desc').value.trim(),
    unitValue: parseFloat(document.getElementById('fund-unit-value').value),
    monthlyContribution: parseFloat(document.getElementById('fund-monthly').value),
    startDate: document.getElementById('fund-start-date').value,
    totalValue: 0,
  });
  closeModal('add-fund-modal');
  document.getElementById('add-fund-form').reset();
  setDefaultDates();
  renderAll();
  toast('تم إنشاء الصندوق بنجاح', 'success');
}

/* ---- Add Member ---- */
function showAddMemberModal() {
  showModal('add-member-modal');
}

function submitAddMember(e) {
  e.preventDefault();
  if (!currentFundId) return;
  DB.addMemberToFund(currentFundId, {
    name: document.getElementById('member-name').value.trim(),
    units: parseFloat(document.getElementById('member-units').value),
    accessCode: document.getElementById('member-code').value.trim(),
    joinDate: document.getElementById('member-join-date').value,
  });
  closeModal('add-member-modal');
  document.getElementById('add-member-form').reset();
  setDefaultDates();
  renderAll();
  openFund(currentFundId);
  toast('تمت إضافة العضو', 'success');
}

/* ---- Record Payment ---- */
function showRecordPaymentModal() {
  if (!currentFundId) return;
  const fund = DB.getFund(currentFundId);
  if (!fund) return;
  const sel = document.getElementById('payment-member');
  sel.innerHTML = fund.members.map(m =>
    `<option value="${m.id}" data-name="${m.name}">${m.name}</option>`
  ).join('');
  // Pre-fill amount with monthly contribution
  document.getElementById('payment-amount').value = fund.monthlyContribution || 500;
  showModal('record-payment-modal');
}

function submitRecordPayment(e) {
  e.preventDefault();
  if (!currentFundId) return;
  const memberSel = document.getElementById('payment-member');
  const memberId = memberSel.value;
  const memberName = memberSel.options[memberSel.selectedIndex].dataset.name;
  DB.recordPayment(currentFundId, {
    memberId,
    memberName,
    amount: parseFloat(document.getElementById('payment-amount').value),
    month: document.getElementById('payment-month').value,
    status: document.getElementById('payment-status').value,
    notes: document.getElementById('payment-notes').value.trim(),
  });
  closeModal('record-payment-modal');
  document.getElementById('record-payment-form').reset();
  setDefaultDates();
  renderAll();
  openFund(currentFundId);
  toast('تم تسجيل الدفعة', 'success');
}

/* ---- Add Zakat ---- */
function submitAddZakat(e) {
  e.preventDefault();
  DB.addZakat({
    year: document.getElementById('zakat-year').value.trim(),
    base: parseFloat(document.getElementById('zakat-base').value),
    amount: parseFloat(document.getElementById('zakat-amount').value),
    status: document.getElementById('zakat-payment-status').value,
    payDate: document.getElementById('zakat-pay-date').value,
  });
  closeModal('add-zakat-modal');
  document.getElementById('add-zakat-form').reset();
  setDefaultDates();
  renderAll();
  toast('تم تسجيل الزكاة', 'success');
}

/* ---- Add Loan ---- */
function submitAddLoan(e) {
  e.preventDefault();
  DB.addLoan({
    borrower: document.getElementById('loan-borrower').value.trim(),
    amount: parseFloat(document.getElementById('loan-amount').value),
    installments: parseInt(document.getElementById('loan-installments').value),
    startDate: document.getElementById('loan-start-date').value,
    purpose: document.getElementById('loan-purpose').value.trim(),
  });
  closeModal('add-loan-modal');
  document.getElementById('add-loan-form').reset();
  setDefaultDates();
  renderAll();
  toast('تم منح القرض', 'success');
}

/* ---- Pay Loan Installment ---- */
function payInstallment(loanId, monthIdx) {
  DB.payLoanInstallment(loanId, monthIdx);
  renderAll();
  toast('تم تسجيل الدفع', 'success');
}

/* ---- Export Data ---- */
function exportData() {
  const data = {
    assets: DB.getAssets(),
    funds: DB.getFunds(),
    zakat: DB.getZakat(),
    loans: DB.getLoans(),
    exportDate: new Date().toISOString(),
  };
  const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = 'investtracker-backup-' + new Date().toISOString().split('T')[0] + '.json';
  a.click();
  URL.revokeObjectURL(url);
  toast('تم تصدير البيانات', 'success');
}

/* ============ UTILITIES ============ */
function fmt(n) {
  if (typeof n !== 'number' || isNaN(n)) return '0 ر.س';
  return n.toLocaleString('ar-SA', { minimumFractionDigits: 0, maximumFractionDigits: 2 }) + ' ر.س';
}

function fmtNum(n) {
  if (typeof n !== 'number' || isNaN(n)) return '0';
  return n.toLocaleString('ar-SA', { minimumFractionDigits: 0, maximumFractionDigits: 4 });
}

function formatDate(d) {
  if (!d) return '-';
  try {
    return new Date(d).toLocaleDateString('ar-SA');
  } catch { return d; }
}

function toast(msg, type = '') {
  const el = document.getElementById('toast');
  el.textContent = msg;
  el.className = 'toast' + (type ? ' ' + type : '');
  setTimeout(() => el.classList.add('hidden'), 3000);
}
