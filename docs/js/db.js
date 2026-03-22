/* ============================================
   InvestTracker - LocalStorage Database Layer
   ============================================ */

const DB = {
  // ---- Keys ----
  KEYS: {
    ASSETS: 'it_assets',
    FUNDS: 'it_funds',
    ZAKAT: 'it_zakat',
    LOANS: 'it_loans',
    TRANSACTIONS: 'it_transactions',
  },

  // ---- Helpers ----
  _get(key) {
    try {
      return JSON.parse(localStorage.getItem(key)) || [];
    } catch { return []; }
  },

  _set(key, data) {
    localStorage.setItem(key, JSON.stringify(data));
  },

  _id() {
    return Date.now().toString(36) + Math.random().toString(36).slice(2, 7);
  },

  // ============ ASSETS ============

  getAssets() { return this._get(this.KEYS.ASSETS); },

  addAsset(asset) {
    const assets = this.getAssets();
    const newAsset = {
      id: this._id(),
      createdAt: new Date().toISOString(),
      ...asset,
    };
    assets.push(newAsset);
    this._set(this.KEYS.ASSETS, assets);
    // Log transaction
    this.addTransaction({
      type: 'BUY',
      assetId: newAsset.id,
      assetName: newAsset.name,
      quantity: newAsset.quantity,
      price: newAsset.buyPrice,
      total: newAsset.quantity * newAsset.buyPrice,
      date: newAsset.date,
    });
    return newAsset;
  },

  updateAsset(id, updates) {
    const assets = this.getAssets();
    const idx = assets.findIndex(a => a.id === id);
    if (idx === -1) return null;
    assets[idx] = { ...assets[idx], ...updates };
    this._set(this.KEYS.ASSETS, assets);
    return assets[idx];
  },

  deleteAsset(id) {
    const assets = this.getAssets().filter(a => a.id !== id);
    this._set(this.KEYS.ASSETS, assets);
  },

  // ============ FUNDS ============

  getFunds() { return this._get(this.KEYS.FUNDS); },

  getFund(id) { return this.getFunds().find(f => f.id === id) || null; },

  addFund(fund) {
    const funds = this.getFunds();
    const newFund = {
      id: this._id(),
      createdAt: new Date().toISOString(),
      members: [],
      payments: [],
      totalValue: 0,
      ...fund,
    };
    funds.push(newFund);
    this._set(this.KEYS.FUNDS, funds);
    return newFund;
  },

  updateFund(id, updates) {
    const funds = this.getFunds();
    const idx = funds.findIndex(f => f.id === id);
    if (idx === -1) return null;
    funds[idx] = { ...funds[idx], ...updates };
    this._set(this.KEYS.FUNDS, funds);
    return funds[idx];
  },

  deleteFund(id) {
    const funds = this.getFunds().filter(f => f.id !== id);
    this._set(this.KEYS.FUNDS, funds);
  },

  addMemberToFund(fundId, member) {
    const fund = this.getFund(fundId);
    if (!fund) return null;
    const newMember = {
      id: this._id(),
      joinedAt: new Date().toISOString(),
      ...member,
    };
    fund.members.push(newMember);
    this.updateFund(fundId, { members: fund.members });
    return newMember;
  },

  recordPayment(fundId, payment) {
    const fund = this.getFund(fundId);
    if (!fund) return null;
    const newPayment = {
      id: this._id(),
      recordedAt: new Date().toISOString(),
      ...payment,
    };
    fund.payments.push(newPayment);
    // Update totalValue
    if (payment.status === 'paid' || payment.status === 'partial') {
      fund.totalValue = (fund.totalValue || 0) + payment.amount;
    }
    this.updateFund(fundId, { payments: fund.payments, totalValue: fund.totalValue });
    return newPayment;
  },

  // ============ ZAKAT ============

  getZakat() { return this._get(this.KEYS.ZAKAT); },

  addZakat(zakat) {
    const list = this.getZakat();
    const item = {
      id: this._id(),
      createdAt: new Date().toISOString(),
      ...zakat,
    };
    list.push(item);
    this._set(this.KEYS.ZAKAT, list);
    return item;
  },

  updateZakat(id, updates) {
    const list = this.getZakat();
    const idx = list.findIndex(z => z.id === id);
    if (idx === -1) return null;
    list[idx] = { ...list[idx], ...updates };
    this._set(this.KEYS.ZAKAT, list);
    return list[idx];
  },

  // ============ LOANS ============

  getLoans() { return this._get(this.KEYS.LOANS); },

  addLoan(loan) {
    const loans = this.getLoans();
    const installmentAmount = loan.amount / loan.installments;
    const schedule = [];
    const start = new Date(loan.startDate);
    for (let i = 0; i < loan.installments; i++) {
      const d = new Date(start);
      d.setMonth(d.getMonth() + i);
      schedule.push({
        month: i + 1,
        dueDate: d.toISOString().split('T')[0],
        amount: installmentAmount,
        paid: false,
        paidDate: null,
      });
    }
    const newLoan = {
      id: this._id(),
      createdAt: new Date().toISOString(),
      schedule,
      paidAmount: 0,
      status: 'active',
      ...loan,
    };
    loans.push(newLoan);
    this._set(this.KEYS.LOANS, loans);
    return newLoan;
  },

  payLoanInstallment(loanId, monthIndex) {
    const loans = this.getLoans();
    const idx = loans.findIndex(l => l.id === loanId);
    if (idx === -1) return null;
    const loan = loans[idx];
    if (loan.schedule[monthIndex]) {
      loan.schedule[monthIndex].paid = true;
      loan.schedule[monthIndex].paidDate = new Date().toISOString().split('T')[0];
      loan.paidAmount = loan.schedule.filter(s => s.paid).length * (loan.amount / loan.installments);
      if (loan.paidAmount >= loan.amount) loan.status = 'completed';
    }
    loans[idx] = loan;
    this._set(this.KEYS.LOANS, loans);
    return loan;
  },

  // ============ TRANSACTIONS ============

  getTransactions() { return this._get(this.KEYS.TRANSACTIONS); },

  addTransaction(tx) {
    const txs = this.getTransactions();
    txs.unshift({ id: this._id(), createdAt: new Date().toISOString(), ...tx });
    // Keep last 200
    this._set(this.KEYS.TRANSACTIONS, txs.slice(0, 200));
  },

  // ============ COMPUTED ============

  getPortfolioStats() {
    const assets = this.getAssets();
    let totalValue = 0, totalCost = 0;
    const byType = {};
    assets.forEach(a => {
      const value = a.quantity * a.currentPrice;
      const cost = a.quantity * a.buyPrice;
      totalValue += value;
      totalCost += cost;
      if (!byType[a.type]) byType[a.type] = 0;
      byType[a.type] += value;
    });
    return {
      totalValue,
      totalCost,
      pnl: totalValue - totalCost,
      pnlPct: totalCost > 0 ? ((totalValue - totalCost) / totalCost) * 100 : 0,
      byType,
    };
  },

  getFundStats(fund) {
    const totalUnits = fund.members.reduce((s, m) => s + (m.units || 0), 0);
    const nav = totalUnits > 0 ? (fund.totalValue || 0) / totalUnits : fund.unitValue || 1000;
    return {
      totalUnits,
      nav,
      totalValue: fund.totalValue || 0,
      membersCount: fund.members.length,
    };
  },

  getZakatStats(goldPrice = 220) {
    const nisab = 85 * goldPrice;
    const assets = this.getAssets();
    const zakatRecords = this.getZakat();

    let zakatableBase = 0;
    assets.forEach(a => {
      // Zakat on market value for stocks/funds, cost for gold
      const val = a.type === 'GOLD'
        ? a.quantity * goldPrice
        : a.quantity * a.currentPrice;
      zakatableBase += val;
    });

    const zakatDue = zakatableBase >= nisab ? zakatableBase * 0.025 : 0;
    const zakatPaid = zakatRecords
      .filter(z => z.status === 'paid' || z.status === 'partial')
      .reduce((s, z) => s + (z.amount || 0), 0);

    return {
      nisab,
      zakatableBase,
      zakatDue,
      zakatPaid,
      zakatRemaining: Math.max(0, zakatDue - zakatPaid),
      meetsNisab: zakatableBase >= nisab,
    };
  },

  getLoanStats() {
    const loans = this.getLoans().filter(l => l.status === 'active');
    const total = loans.reduce((s, l) => s + l.amount, 0);
    const remaining = loans.reduce((s, l) => s + (l.amount - l.paidAmount), 0);
    const paid = loans.reduce((s, l) => s + l.paidAmount, 0);
    const today = new Date().toISOString().split('T')[0];
    let overdue = 0;
    loans.forEach(l => {
      l.schedule.forEach(s => {
        if (!s.paid && s.dueDate < today) overdue++;
      });
    });
    return { total, remaining, paid, overdue };
  },

  // ============ SEED DATA ============

  seedDemoData() {
    if (this.getAssets().length > 0) return; // Already has data

    // Demo assets
    [
      { name: 'أرامكو السعودية', symbol: '2222.SR', type: 'SA_STOCK', quantity: 100, buyPrice: 32, currentPrice: 28.5, date: '2024-01-15', notes: '' },
      { name: 'صندوق الراجحي', symbol: 'RIBL', type: 'FUND', quantity: 500, buyPrice: 10, currentPrice: 11.2, date: '2024-03-01', notes: '' },
      { name: 'ذهب (جرام)', symbol: 'GOLD', type: 'GOLD', quantity: 50, buyPrice: 195, currentPrice: 220, date: '2023-11-10', notes: '' },
      { name: 'Apple Inc', symbol: 'AAPL', type: 'US_STOCK', quantity: 10, buyPrice: 180, currentPrice: 210, date: '2024-02-20', notes: '' },
      { name: 'نقد احتياطي', symbol: '', type: 'CASH', quantity: 1, buyPrice: 5000, currentPrice: 5000, date: '2024-01-01', notes: '' },
    ].forEach(a => this.addAsset(a));

    // Demo fund
    const fund = this.addFund({
      name: 'صندوق العائلة',
      description: 'صندوق استثماري عائلي مشترك',
      unitValue: 1000,
      monthlyContribution: 500,
      startDate: '2023-01-01',
      totalValue: 45000,
    });

    // Demo members
    [
      { name: 'عبدالله العمري', units: 2, accessCode: '123456', joinDate: '2023-01-01' },
      { name: 'محمد القحطاني', units: 1, accessCode: '234567', joinDate: '2023-01-01' },
      { name: 'سارة الزهراني', units: 3, accessCode: '345678', joinDate: '2023-03-01' },
    ].forEach(m => this.addMemberToFund(fund.id, m));

    // Demo payments
    [
      { memberId: fund.members[0]?.id, memberName: 'عبدالله العمري', amount: 1000, month: '2024-01', status: 'paid', notes: '' },
      { memberId: fund.members[1]?.id, memberName: 'محمد القحطاني', amount: 500, month: '2024-01', status: 'paid', notes: '' },
      { memberId: fund.members[2]?.id, memberName: 'سارة الزهراني', amount: 1500, month: '2024-01', status: 'partial', notes: 'دفع جزء' },
    ].forEach(p => this.recordPayment(fund.id, p));

    // Demo zakat
    this.addZakat({
      year: '1445',
      base: 72000,
      amount: 1800,
      status: 'paid',
      payDate: '2024-04-01',
    });

    // Demo loan
    this.addLoan({
      borrower: 'محمد القحطاني',
      amount: 6000,
      installments: 12,
      startDate: '2024-01-01',
      purpose: 'تغطية نفقات طارئة',
    });
  },
};
