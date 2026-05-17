<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*" %>
<%@ page import="java.sql.*" %>
<%@ include file="../basedados/basedados.h" %>
<%
    // Session check
    HttpSession sessao = request.getSession(false);
    Integer userId = (sessao != null) ? (Integer) sessao.getAttribute("userId") : null;
    if (userId == null) {
        response.sendRedirect("login.jsp");
        return;
    }
    String clienteName = (String) sessao.getAttribute("userName");

    String successMsg = (String) sessao.getAttribute("success");
    if (successMsg != null) sessao.removeAttribute("success");
    String errorMsg = null;

    if ("POST".equalsIgnoreCase(request.getMethod())) {
        String acao = request.getParameter("action");
        String valorStr = request.getParameter("valor");
        try {
            if (valorStr == null || valorStr.isBlank()) throw new Exception("Valor inválido.");
            double valor = Double.parseDouble(valorStr.replace(",", "."));
            if (valor <= 0) throw new Exception("O valor deve ser superior a 0.");

            Connection connPost = getConnection();

            PreparedStatement psPost = connPost.prepareStatement("SELECT id_carteira FROM carteira WHERE id_utilizador = ?");
            psPost.setInt(1, userId); ResultSet rsPost = psPost.executeQuery();
            int userCartId = rsPost.next() ? rsPost.getInt("id_carteira") : -1; rsPost.close(); psPost.close();

            psPost = connPost.prepareStatement("SELECT id_carteira FROM carteira WHERE is_loja = 1 LIMIT 1");
            rsPost = psPost.executeQuery(); int lojaCartId = rsPost.next() ? rsPost.getInt("id_carteira") : -1; rsPost.close(); psPost.close();

            if ("adicionar".equals(acao)) {
                psPost = connPost.prepareStatement("UPDATE carteira SET saldo = saldo + ? WHERE id_carteira = ?");
                psPost.setDouble(1, valor); psPost.setInt(2, userCartId); psPost.executeUpdate(); psPost.close();
                psPost = connPost.prepareStatement("INSERT INTO auditoria_carteira (id_carteira_origem, id_carteira_destino, valor, tipo_operacao, descricao) VALUES (?,?,?,'deposito',?)");
                psPost.setInt(1, lojaCartId); psPost.setInt(2, userCartId); psPost.setDouble(3, valor);
                psPost.setString(4, "Depósito na carteira"); psPost.executeUpdate(); closeAll(null, psPost, connPost);
                sessao.setAttribute("success", String.format("Depósito de %.2f € realizado.", valor).replace(".", ","));
            } else if ("levantar".equals(acao)) {
                psPost = connPost.prepareStatement("SELECT saldo FROM carteira WHERE id_carteira = ?");
                psPost.setInt(1, userCartId); rsPost = psPost.executeQuery();
                double saldoAtual = rsPost.next() ? rsPost.getDouble("saldo") : 0; rsPost.close(); psPost.close();
                if (valor > saldoAtual) throw new Exception("Saldo insuficiente.");
                psPost = connPost.prepareStatement("UPDATE carteira SET saldo = saldo - ? WHERE id_carteira = ?");
                psPost.setDouble(1, valor); psPost.setInt(2, userCartId); psPost.executeUpdate(); psPost.close();
                psPost = connPost.prepareStatement("INSERT INTO auditoria_carteira (id_carteira_origem, id_carteira_destino, valor, tipo_operacao, descricao) VALUES (?,?,?,'levantamento',?)");
                psPost.setInt(1, userCartId); psPost.setInt(2, lojaCartId); psPost.setDouble(3, valor);
                psPost.setString(4, "Levantamento da carteira"); psPost.executeUpdate(); closeAll(null, psPost, connPost);
                sessao.setAttribute("success", String.format("Levantamento de %.2f € realizado.", valor).replace(".", ","));
            }
            response.sendRedirect("carteira.jsp"); return;
        } catch (Exception e) { errorMsg = e.getMessage(); }
    }

    int    saldoCents = 0;
    String saldoStr   = "0,00 €";
    int    carteiraId = -1;
    List<String[]> historyList = new ArrayList<>();

    Connection conn = null;
    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        conn = getConnection();

        // Get user's carteira
        ps = conn.prepareStatement(
            "SELECT c.id_carteira, c.saldo FROM carteira c WHERE c.id_utilizador = ?");
        ps.setInt(1, userId);
        rs = ps.executeQuery();
        if (rs.next()) {
            carteiraId = rs.getInt("id_carteira");
            double saldo = rs.getDouble("saldo");
            saldoCents = (int)(saldo * 100);
            saldoStr = String.format("%d,%02d €", saldoCents / 100, saldoCents % 100);
        }
        closeResultSet(rs); rs = null;
        closeStatement(ps); ps = null;

        // Get movement history
        if (carteiraId != -1) {
            ps = conn.prepareStatement(
                "SELECT ac.data_operacao, ac.tipo_operacao, ac.descricao, ac.valor," +
                "       ac.id_carteira_origem, ac.id_carteira_destino" +
                " FROM auditoria_carteira ac" +
                " WHERE ac.id_carteira_origem = ? OR ac.id_carteira_destino = ?" +
                " ORDER BY ac.data_operacao DESC LIMIT 20");
            ps.setInt(1, carteiraId);
            ps.setInt(2, carteiraId);
            rs = ps.executeQuery();
            while (rs.next()) {
                String dataOp   = rs.getString("data_operacao");
                if (dataOp != null && dataOp.length() > 16) dataOp = dataOp.substring(0, 16).replace('T', ' ');
                String tipoOp   = rs.getString("tipo_operacao");
                String descricao = rs.getString("descricao");
                if (descricao == null || descricao.isEmpty()) descricao = tipoOp;
                double valor    = rs.getDouble("valor");
                int    origId   = rs.getInt("id_carteira_origem");
                boolean isDebit = (origId == carteiraId);
                String sign     = isDebit ? "-" : "+";
                String valorFmt = sign + String.format("%.2f €", valor).replace(".", ",");
                historyList.add(new String[]{dataOp, descricao, "—", "Carteira", valorFmt});
            }
        }
    } catch (Exception e) {
        errorMsg = "Erro ao carregar carteira: " + e.getMessage();
    } finally {
        closeAll(rs, ps, conn);
    }

    String[][] history = historyList.toArray(new String[0][]);
    String activePage = "carteira";
%>
<!DOCTYPE html>
<html lang="pt">
<head>
    <meta charset="UTF-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <title>FelixUberShop – Carteira</title>
    <style>
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

        body {
            background-color: #212121; color: #e0e0e0;
            font-family: 'Segoe UI', Arial, sans-serif;
            min-height: 100vh; display: flex; flex-direction: column;
        }

        .topnav {
            background: #2a2a2a; border-bottom: 1px solid #333;
            height: 52px; display: flex; align-items: center;
            justify-content: space-between; padding: 0 24px;
            position: sticky; top: 0; z-index: 200;
        }
        .nav-brand { font-size: 1.2rem; font-weight: 700; color: #00CE86; text-decoration: none; }
        .nav-right  { display: flex; align-items: center; gap: 18px; }
        .nav-user   { display: flex; align-items: center; gap: 8px; font-size: .87rem; color: #bbb; }
        .nav-user svg { fill: #00CE86; width: 20px; height: 20px; }
        .btn-sair {
            background: none; border: 1px solid #555; color: #aaa;
            font-size: .8rem; padding: 5px 14px; border-radius: 6px;
            cursor: pointer; text-decoration: none;
            transition: border-color .2s, color .2s;
        }
        .btn-sair:hover { border-color: #e05555; color: #e05555; }

        .app-shell { display: flex; flex: 1; min-height: 0; }

        .sidebar {
            width: 210px; flex-shrink: 0; background: #111;
            border-right: 1px solid #222;
            display: flex; flex-direction: column; padding: 24px 0 16px;
        }
        .sidebar-label {
            font-size: .68rem; font-weight: 700; letter-spacing: 1.2px;
            color: #444; text-transform: uppercase; padding: 0 20px 14px;
        }
        .sidebar-nav { list-style: none; }
        .sidebar-nav li a {
            display: flex; align-items: center; gap: 11px;
            padding: 11px 20px; text-decoration: none;
            font-size: .88rem; color: #888;
            border-left: 3px solid transparent;
            transition: background .15s, color .15s, border-color .15s;
        }
        .sidebar-nav li a:hover { background: rgba(255,255,255,.04); color: #ddd; }
        .sidebar-nav li a.active {
            border-left-color: #00CE86; background: rgba(0,206,134,.07);
            color: #00CE86; font-weight: 600;
        }
        .sidebar-nav li a svg { width: 17px; height: 17px; fill: currentColor; flex-shrink: 0; }

        .main-content { flex: 1; padding: 26px 26px 48px; overflow-y: auto; min-width: 0; }
        .page-title { font-size: 1.3rem; font-weight: 700; color: #fff; margin-bottom: 20px; }

        .alert {
            border-radius: 8px; padding: 11px 16px; font-size: .86rem;
            margin-bottom: 18px; display: flex; align-items: center; gap: 10px;
        }
        .alert svg { width: 16px; height: 16px; flex-shrink: 0; }
        .alert-success { background: rgba(0,206,134,.1);  border: 1px solid rgba(0,206,134,.3);  color: #00CE86; }
        .alert-error   { background: rgba(220,60,60,.1);  border: 1px solid rgba(220,60,60,.3);  color: #f08080; }

        .wallet-top {
            display: grid;
            grid-template-columns: 200px 1fr 1fr;
            gap: 14px;
            margin-bottom: 22px;
            align-items: stretch;
        }

        .wallet-card {
            background: #2b2b2b; border: 1px solid #333; border-radius: 10px;
            padding: 18px 20px;
        }

        .balance-card { display: flex; flex-direction: column; justify-content: center; }

        .balance-label {
            font-size: .68rem; font-weight: 700; letter-spacing: .8px;
            text-transform: uppercase; color: #555; margin-bottom: 8px;
        }
        .balance-value {
            font-size: 2.1rem; font-weight: 700; color: #00CE86; line-height: 1;
        }
        .balance-sub {
            font-size: .75rem; color: #666; margin-top: 6px;
            display: flex; align-items: center; gap: 5px;
        }
        .balance-sub svg { fill: #555; width: 12px; height: 12px; }

        .action-card { display: flex; flex-direction: column; gap: 10px; }

        .action-label {
            font-size: .68rem; font-weight: 700; letter-spacing: .8px;
            text-transform: uppercase; color: #555;
            display: flex; align-items: center; gap: 6px;
        }
        .action-label svg { fill: currentColor; width: 13px; height: 13px; }
        .action-label.add-lbl { color: #00CE86; }
        .action-label.rem-lbl { color: #e07070; }

        .action-input-row { display: flex; gap: 8px; align-items: center; }

        .money-wrap { position: relative; flex: 1; }
        .money-wrap .currency {
            position: absolute; left: 10px; top: 50%; transform: translateY(-50%);
            font-size: .85rem; color: #555; font-weight: 600; pointer-events: none;
        }
        .money-input {
            width: 100%; background: #1a1a1a; border: 1px solid #3a3a3a;
            border-radius: 7px; color: #fff; font-size: .92rem; font-weight: 700;
            padding: 9px 10px 9px 22px; outline: none;
            transition: border-color .2s, box-shadow .2s;
        }
        .money-input:focus { border-color: #00CE86; box-shadow: 0 0 0 3px rgba(0,206,134,.12); }
        .money-input.rem-field:focus { border-color: #e05555; box-shadow: 0 0 0 3px rgba(220,60,60,.1); }

        .btn-add {
            background: #00CE86; color: #111; border: none;
            border-radius: 7px; padding: 9px 16px; font-size: .84rem;
            font-weight: 700; cursor: pointer; white-space: nowrap;
            flex-shrink: 0; transition: background .2s;
        }
        .btn-add:hover { background: #00b876; }

        .btn-rem {
            background: none; border: 1px solid #7a3030; color: #e07070;
            border-radius: 7px; padding: 9px 16px; font-size: .84rem;
            font-weight: 700; cursor: pointer; white-space: nowrap;
            flex-shrink: 0; transition: background .2s, border-color .2s;
        }
        .btn-rem:hover { background: rgba(220,60,60,.1); border-color: #e05555; }

        .action-hint { font-size: .74rem; color: #555; display: flex; align-items: center; gap: 5px; }
        .action-hint svg { fill: #444; width: 12px; height: 12px; flex-shrink: 0; }

        .action-error {
            font-size: .74rem; color: #f5a623;
            display: none; align-items: center; gap: 5px;
        }
        .action-error.visible { display: flex; }
        .action-error svg { fill: #f5a623; width: 12px; height: 12px; }

        .panel { background: #2b2b2b; border: 1px solid #333; border-radius: 10px; overflow: hidden; }

        .panel-header {
            padding: 13px 18px; border-bottom: 1px solid #333;
            display: flex; align-items: center; justify-content: space-between;
        }
        .panel-title { font-size: .9rem; font-weight: 700; color: #e8e8e8; display: flex; align-items: center; gap: 8px; }
        .panel-title svg { fill: #00CE86; width: 16px; height: 16px; }

        .history-table { width: 100%; border-collapse: collapse; }

        .history-table th {
            padding: 9px 16px; font-size: .7rem; font-weight: 700;
            letter-spacing: .6px; text-transform: uppercase;
            color: #555; text-align: left;
            border-bottom: 1px solid #333; background: #252525;
            white-space: nowrap;
        }

        .history-table td {
            padding: 12px 16px; font-size: .86rem; color: #bbb;
            border-bottom: 1px solid #272727; vertical-align: middle;
        }
        .history-table tr:last-child td { border-bottom: none; }
        .history-table tr:hover td { background: rgba(255,255,255,.02); }

        .date-cell { color: #888; font-size: .79rem; white-space: nowrap; }

        .op-cell { display: flex; align-items: center; gap: 9px; }
        .op-icon {
            width: 30px; height: 30px; border-radius: 50%;
            display: flex; align-items: center; justify-content: center; flex-shrink: 0;
        }
        .op-icon svg { width: 14px; height: 14px; fill: currentColor; }
        .op-icon.credit  { background: rgba(0,206,134,.1);  color: #00CE86; }
        .op-icon.debit   { background: rgba(220,80,80,.1);  color: #e07070; }
        .op-icon.neutral { background: rgba(100,150,255,.1); color: #7aadff; }

        .op-name { color: #ddd; font-size: .85rem; font-weight: 500; }

        .wallet-col {
            font-size: .81rem; color: #666;
            display: flex; align-items: center; gap: 5px;
        }
        .wallet-col svg { fill: #444; width: 12px; height: 12px; flex-shrink: 0; }
        .wallet-col.highlighted { color: #aaa; }
        .wallet-nil { color: #333; }

        .value-cell { font-weight: 700; white-space: nowrap; text-align: right; }
        .value-pos  { color: #00CE86; }
        .value-neg  { color: #e07070; }

        .empty-state {
            padding: 40px 20px; text-align: center; color: #555;
        }
        .empty-state svg { fill: #2e2e2e; width: 44px; height: 44px; margin-bottom: 12px; display: block; margin-inline: auto; }

        @media (max-width: 680px) {
            .wallet-top { grid-template-columns: 1fr; }
            .sidebar { width: 56px; }
            .sidebar-label, .sidebar-nav li a span { display: none; }
            .sidebar-nav li a { padding: 13px; justify-content: center; }
            .main-content { padding: 14px; }
            .history-table th:nth-child(3),
            .history-table td:nth-child(3),
            .history-table th:nth-child(4),
            .history-table td:nth-child(4) { display: none; }
        }
    </style>
</head>
<body>

    <!-- NAV -->
    <nav class="topnav">
        <a href="index.jsp" class="nav-brand">FelixUberShop</a>
        <div class="nav-right">
            <div class="nav-user">
                <svg viewBox="0 0 24 24"><path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/></svg>
                Olá, <strong style="color:#e0e0e0;margin-left:4px;"><%= clienteName %></strong>
            </div>
            <a href="logout.jsp" class="btn-sair">Sair</a>
        </div>
    </nav>

    <div class="app-shell">

        <!-- SIDEBAR -->
        <aside class="sidebar">
            <div class="sidebar-label">Área Cliente</div>
            <ul class="sidebar-nav">
                <li><a href="dashboard.jsp" class="<%= "dashboard".equals(activePage)?"active":"" %>">
                    <svg viewBox="0 0 24 24"><path d="M3 13h8V3H3v10zm0 8h8v-6H3v6zm10 0h8V11h-8v10zm0-18v6h8V3h-8z"/></svg>
                    <span>Dashboard</span>
                </a></li>
                <li><a href="perfil.jsp" class="<%= "perfil".equals(activePage)?"active":"" %>">
                    <svg viewBox="0 0 24 24"><path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/></svg>
                    <span>Perfil</span>
                </a></li>
                <li><a href="carteira.jsp" class="<%= "carteira".equals(activePage)?"active":"" %>">
                    <svg viewBox="0 0 24 24"><path d="M21 7H3c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V9c0-1.1-.9-2-2-2zm-1 12H4V9h16v10zm-5-5a2 2 0 1 1 4 0 2 2 0 0 1-4 0zM3 5h16V3H3z"/></svg>
                    <span>Carteira</span>
                </a></li>
                <li><a href="encomendas.jsp" class="<%= "encomendas".equals(activePage)?"active":"" %>">
                    <svg viewBox="0 0 24 24"><path d="M20 6h-2.18A3 3 0 0 0 15 4H9a3 3 0 0 0-2.82 2H4c-1.1 0-2 .9-2 2v11c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-11 0h6c.55 0 1 .45 1 1s-.45 1-1 1H9c-.55 0-1-.45-1-1s.45-1 1-1zM8 13h8v1.5H8V13zm0 3h5v1.5H8V16z"/></svg>
                    <span>Encomendas</span>
                </a></li>
            </ul>
        </aside>

        <!-- MAIN -->
        <main class="main-content">
            <h1 class="page-title">Carteira</h1>

            <!-- Alerts -->
            <% if (successMsg != null && !successMsg.isEmpty()) { %>
            <div class="alert alert-success">
                <svg viewBox="0 0 24 24" fill="#00CE86"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 14l-4-4 1.41-1.41L10 13.17l6.59-6.59L18 8l-8 8z"/></svg>
                <%= successMsg %>
            </div>
            <% } %>
            <% if (errorMsg != null && !errorMsg.isEmpty()) { %>
            <div class="alert alert-error">
                <svg viewBox="0 0 24 24" fill="#f08080"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/></svg>
                <%= errorMsg %>
            </div>
            <% } %>

            <!-- TOP CARDS -->
            <div class="wallet-top">

                <!-- SALDO ATUAL -->
                <div class="wallet-card balance-card">
                    <div class="balance-label">Saldo Atual</div>
                    <div class="balance-value" id="liveBalance"><%= saldoStr %></div>
                    <div class="balance-sub">
                        <svg viewBox="0 0 24 24"><path d="M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zM12 20c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8zm.5-13H11v6l5.25 3.15.75-1.23-4.5-2.67V7z"/></svg>
                        Atualizado agora
                    </div>
                </div>

                <!-- ADICIONAR SALDO -->
                <div class="wallet-card action-card">
                    <div class="action-label add-lbl">
                        <svg viewBox="0 0 24 24"><path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z"/></svg>
                        Adicionar Saldo
                    </div>
                    <form action="carteira.jsp" method="post"
                          onsubmit="return confirmOp('adicionar')">
                        <input type="hidden" name="action" value="adicionar"/>
                        <div class="action-input-row">
                            <div class="money-wrap">
                                <span class="currency">€</span>
                                <input type="number" name="valor" id="addValor"
                                       class="money-input" step="0.01" min="0.01"
                                       placeholder="0,00" required/>
                            </div>
                            <button type="submit" class="btn-add">Adicionar</button>
                        </div>
                    </form>
                    <div class="action-hint">
                        <svg viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z"/></svg>
                        Transferência simulada
                    </div>
                </div>

                <!-- LEVANTAR SALDO -->
                <div class="wallet-card action-card">
                    <div class="action-label rem-lbl">
                        <svg viewBox="0 0 24 24"><path d="M19 13H5v-2h14v2z"/></svg>
                        Levantar Saldo
                    </div>
                    <form action="carteira.jsp" method="post"
                          onsubmit="return confirmOp('levantar')">
                        <input type="hidden" name="action" value="levantar"/>
                        <div class="action-input-row">
                            <div class="money-wrap">
                                <span class="currency">€</span>
                                <input type="number" name="valor" id="remValor"
                                       class="money-input rem-field" step="0.01" min="0.01"
                                       placeholder="0,00" required
                                       oninput="checkSaldo(this)"/>
                            </div>
                            <button type="submit" class="btn-rem" id="btnLev">Levantar</button>
                        </div>
                    </form>
                    <div class="action-error" id="saldoInsuf">
                        <svg viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/></svg>
                        Saldo insuficiente.
                    </div>
                    <div class="action-hint" id="levHint">
                        <svg viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z"/></svg>
                        Transferência simulada
                    </div>
                </div>

            </div><!-- end wallet-top -->

            <!-- HISTORY TABLE -->
            <div class="panel">
                <div class="panel-header">
                    <div class="panel-title">
                        <svg viewBox="0 0 24 24"><path d="M9 17H7v-7h2v7zm4 0h-2V7h2v10zm4 0h-2v-4h2v4zm2 2H5V5h14v14zm0-16H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2z"/></svg>
                        Histórico de movimentos (auditoria)
                    </div>
                </div>

                <% if (history.length == 0) { %>
                <div class="empty-state">
                    <svg viewBox="0 0 24 24"><path d="M21 7H3c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V9c0-1.1-.9-2-2-2z"/></svg>
                    <p>Sem movimentos registados.</p>
                </div>
                <% } else { %>
                <table class="history-table">
                    <thead>
                        <tr>
                            <th>Data / Hora</th>
                            <th>Operação</th>
                            <th>Carteira Origem</th>
                            <th>Carteira Destino</th>
                            <th style="text-align:right;">Valor</th>
                        </tr>
                    </thead>
                    <tbody>
                        <%
                            for (String[] h : history) {
                                String hdate  = h[0];
                                String hop    = h[1];
                                String hfrom  = h[2];
                                String hto    = h[3];
                                String hval   = h[4];

                                boolean isCredit  = hval.startsWith("+");
                                boolean isDebit   = hval.startsWith("-");

                                String iconClass = isCredit ? "credit" : (isDebit ? "debit" : "neutral");

                                String iconPath;
                                if (hop.toLowerCase().contains("depósito") || hop.toLowerCase().contains("deposito")) {
                                    iconPath = "M20 12l-1.41-1.41L13 16.17V4h-2v12.17l-5.58-5.59L4 12l8 8 8-8z\" transform=\"rotate(180,12,12)";
                                } else if (hop.toLowerCase().contains("levant")) {
                                    iconPath = "M20 12l-1.41-1.41L13 16.17V4h-2v12.17l-5.58-5.59L4 12l8 8 8-8z";
                                } else {
                                    iconPath = "M11.8 10.9c-2.27-.59-3-1.2-3-2.15 0-1.09 1.01-1.85 2.7-1.85 1.78 0 2.44.85 2.5 2.1h2.21c-.07-1.72-1.12-3.3-3.21-3.81V3h-3v2.16C9.56 5.67 8 6.84 8 8.75c0 2.31 1.91 3.46 4.7 4.13 2.5.6 3 1.48 3 2.41 0 .69-.49 1.79-2.7 1.79-2.06 0-2.87-.92-2.98-2.1H7.82c.12 2.19 1.76 3.42 3.68 3.83V21h3v-2.15c1.95-.37 3.5-1.5 3.5-3.55 0-2.84-2.43-3.81-4.7-4.4z";
                                }

                                String valClass = isCredit ? "value-pos" : "value-neg";
                        %>
                        <tr>
                            <td class="date-cell"><%= hdate %></td>
                            <td>
                                <div class="op-cell">
                                    <div class="op-icon <%= iconClass %>">
                                        <svg viewBox="0 0 24 24"><path d="<%= iconPath %>"/></svg>
                                    </div>
                                    <span class="op-name"><%= hop %></span>
                                </div>
                            </td>
                            <td>
                                <% if ("—".equals(hfrom)) { %>
                                <span class="wallet-nil">—</span>
                                <% } else { %>
                                <div class="wallet-col <%= "FelixUberShop".equals(hfrom) ? "" : "highlighted" %>">
                                    <svg viewBox="0 0 24 24"><path d="M21 7H3c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V9c0-1.1-.9-2-2-2zm-1 12H4V9h16v10zm-5-5a2 2 0 1 1 4 0 2 2 0 0 1-4 0zM3 5h16V3H3z"/></svg>
                                    <%= hfrom %>
                                </div>
                                <% } %>
                            </td>
                            <td>
                                <% if ("—".equals(hto)) { %>
                                <span class="wallet-nil">—</span>
                                <% } else { %>
                                <div class="wallet-col <%= "FelixUberShop".equals(hto) ? "" : "highlighted" %>">
                                    <svg viewBox="0 0 24 24"><path d="M21 7H3c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V9c0-1.1-.9-2-2-2zm-1 12H4V9h16v10zm-5-5a2 2 0 1 1 4 0 2 2 0 0 1-4 0zM3 5h16V3H3z"/></svg>
                                    <%= hto %>
                                </div>
                                <% } %>
                            </td>
                            <td class="value-cell <%= valClass %>"><%= hval %></td>
                        </tr>
                        <% } %>
                    </tbody>
                </table>
                <% } %>
            </div>

        </main>
    </div>

    <script>
        const saldoCents = <%= saldoCents %>;

        function checkSaldo(input) {
            const val   = parseFloat(input.value) || 0;
            const insuf = Math.round(val * 100) > saldoCents;
            document.getElementById('saldoInsuf').classList.toggle('visible', insuf);
            document.getElementById('levHint').style.display    = insuf ? 'none'  : '';
            document.getElementById('btnLev').disabled          = insuf;
        }

        function confirmOp(type) {
            const input  = document.getElementById(type === 'adicionar' ? 'addValor' : 'remValor');
            const val    = parseFloat(input.value);
            if (!val || val <= 0) return false;
            if (type === 'levantar' && Math.round(val * 100) > saldoCents) return false;
            const fmt = val.toFixed(2).replace('.', ',');
            const msg = type === 'adicionar'
                ? `Adicionar ${fmt} € ao seu saldo?`
                : `Levantar ${fmt} € do seu saldo?`;
            return confirm(msg);
        }
    </script>

</body>
</html>
