<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*" %>
<%@ include file="../basedados/basedados.h" %>
<%
    // Session check — funcionario role
    HttpSession sessao = request.getSession(false);
    if (sessao == null || !"funcionario".equalsIgnoreCase((String) sessao.getAttribute("userRole"))) {
        response.sendRedirect("login.jsp");
        return;
    }
    String funcName = (String) sessao.getAttribute("userName");

    String successMsg = (String) sessao.getAttribute("success");
    if (successMsg != null) sessao.removeAttribute("success");
    String errorMsg = null;

    if ("POST".equalsIgnoreCase(request.getMethod())) {
        String acao = request.getParameter("action");
        String clienteIdStr = request.getParameter("clienteId");
        String valorStr = request.getParameter("valor");
        try {
            if (clienteIdStr == null || clienteIdStr.isBlank()) throw new Exception("Cliente não selecionado.");
            if (valorStr == null || valorStr.isBlank()) throw new Exception("Valor inválido.");
            int clienteId = Integer.parseInt(clienteIdStr);
            double valor = Double.parseDouble(valorStr.replace(",", "."));
            if (valor <= 0) throw new Exception("O valor deve ser superior a 0.");

            Connection connPost = getConnection();
            PreparedStatement psPost = connPost.prepareStatement("SELECT id_carteira FROM carteira WHERE id_utilizador = ?");
            psPost.setInt(1, clienteId); ResultSet rsPost = psPost.executeQuery();
            int clienteCartId = rsPost.next() ? rsPost.getInt("id_carteira") : -1; rsPost.close(); psPost.close();
            psPost = connPost.prepareStatement("SELECT id_carteira FROM carteira WHERE is_loja = 1 LIMIT 1");
            rsPost = psPost.executeQuery(); int lojaCartId = rsPost.next() ? rsPost.getInt("id_carteira") : -1; rsPost.close(); psPost.close();
            if (clienteCartId < 0) throw new Exception("Carteira do cliente não encontrada.");

            if ("adicionar".equals(acao)) {
                psPost = connPost.prepareStatement("UPDATE carteira SET saldo = saldo + ? WHERE id_carteira = ?");
                psPost.setDouble(1, valor); psPost.setInt(2, clienteCartId); psPost.executeUpdate(); psPost.close();
                psPost = connPost.prepareStatement("INSERT INTO auditoria_carteira (id_carteira_origem, id_carteira_destino, valor, tipo_operacao, descricao) VALUES (?,?,?,'deposito',?)");
                psPost.setInt(1, lojaCartId); psPost.setInt(2, clienteCartId); psPost.setDouble(3, valor);
                psPost.setString(4, "Depósito via funcionário"); psPost.executeUpdate(); closeAll(null, psPost, connPost);
                sessao.setAttribute("success", String.format("Depósito de %.2f € adicionado.", valor).replace(".", ","));
            } else if ("retirar".equals(acao)) {
                psPost = connPost.prepareStatement("SELECT saldo FROM carteira WHERE id_carteira = ?");
                psPost.setInt(1, clienteCartId); rsPost = psPost.executeQuery();
                double saldoAtual = rsPost.next() ? rsPost.getDouble("saldo") : 0; rsPost.close(); psPost.close();
                if (valor > saldoAtual) throw new Exception("Saldo insuficiente.");
                psPost = connPost.prepareStatement("UPDATE carteira SET saldo = saldo - ? WHERE id_carteira = ?");
                psPost.setDouble(1, valor); psPost.setInt(2, clienteCartId); psPost.executeUpdate(); psPost.close();
                psPost = connPost.prepareStatement("INSERT INTO auditoria_carteira (id_carteira_origem, id_carteira_destino, valor, tipo_operacao, descricao) VALUES (?,?,?,'levantamento',?)");
                psPost.setInt(1, clienteCartId); psPost.setInt(2, lojaCartId); psPost.setDouble(3, valor);
                psPost.setString(4, "Retirada via funcionário"); psPost.executeUpdate(); closeAll(null, psPost, connPost);
                sessao.setAttribute("success", String.format("Saldo de %.2f € retirado.", valor).replace(".", ","));
            }
            response.sendRedirect("saldoClientes.jsp?clienteId=" + clienteId); return;
        } catch (Exception e) { errorMsg = e.getMessage(); }
    }

    List<Object[]> clients = new ArrayList<>();

    Connection conn = null;
    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        conn = getConnection();
        ps = conn.prepareStatement(
            "SELECT u.id_utilizador, u.nome, u.email, COALESCE(c.saldo, 0) as saldo" +
            " FROM utilizadores u" +
            " LEFT JOIN carteira c ON c.id_utilizador = u.id_utilizador" +
            " WHERE u.perfil = 'cliente' AND u.ativo = 1" +
            " ORDER BY u.nome");
        rs = ps.executeQuery();
        while (rs.next()) {
            double saldo = rs.getDouble("saldo");
            int saldoCents = (int)(saldo * 100);
            clients.add(new Object[]{
                String.valueOf(rs.getInt("id_utilizador")),
                rs.getString("nome"),
                rs.getString("email"),
                saldoCents
            });
        }
    } catch (Exception e) {
        errorMsg = "Erro ao carregar clientes: " + e.getMessage();
    } finally {
        closeAll(rs, ps, conn);
    }

    String selectedId = request.getParameter("clienteId");
    if ((selectedId == null || selectedId.isEmpty()) && !clients.isEmpty()) {
        selectedId = (String) clients.get(0)[0];
    }
    if (selectedId == null) selectedId = "";

    String selName  = "";
    String selEmail = "";
    int    selSaldo = 0;
    for (Object[] c : clients) {
        if (c[0].equals(selectedId)) {
            selName  = (String)  c[1];
            selEmail = (String)  c[2];
            selSaldo = (Integer) c[3];
            break;
        }
    }

    String filterCliente = request.getParameter("cliente") != null ? request.getParameter("cliente") : "";
    String activePage = "saldo";
%>
<!DOCTYPE html>
<html lang="pt">
<head>
    <meta charset="UTF-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <title>FelixUberShop – Saldo Clientes</title>
    <style>
        *, *::before, *::after {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            background-color: #212121;
            color: #e0e0e0;
            font-family: 'Segoe UI', Arial, sans-serif;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
        }

        .topnav {
            background: #2a2a2a;
            border-bottom: 1px solid #333;
            height: 52px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 0 24px;
            position: sticky;
            top: 0;
            z-index: 200;
        }

        .nav-brand {
            font-size: 1.2rem;
            font-weight: 700;
            color: #00CE86;
            text-decoration: none;
        }

        .nav-right {
            display: flex;
            align-items: center;
            gap: 18px;
        }

        .nav-user {
            display: flex;
            align-items: center;
            gap: 8px;
            font-size: .87rem;
            color: #bbb;
        }

        .nav-user svg {
            fill: #00CE86;
            width: 20px;
            height: 20px;
        }

        .nav-role {
            font-size: .68rem;
            font-weight: 700;
            letter-spacing: .6px;
            background: rgba(0, 206, 134, .12);
            color: #00CE86;
            border: 1px solid rgba(0, 206, 134, .25);
            padding: 2px 8px;
            border-radius: 20px;
            text-transform: uppercase;
        }

        .btn-sair {
            background: none;
            border: 1px solid #555;
            color: #aaa;
            font-size: .8rem;
            padding: 5px 14px;
            border-radius: 6px;
            cursor: pointer;
            text-decoration: none;
            transition: border-color .2s, color .2s;
        }

        .btn-sair:hover {
            border-color: #e05555;
            color: #e05555;
        }

        .app-shell {
            display: flex;
            flex: 1;
            min-height: 0;
        }

        .sidebar {
            width: 215px;
            flex-shrink: 0;
            background: #111;
            border-right: 1px solid #1e1e1e;
            display: flex;
            flex-direction: column;
            padding: 24px 0 16px;
        }

        .sidebar-label {
            font-size: .67rem;
            font-weight: 700;
            letter-spacing: 1.2px;
            color: #3a3a3a;
            text-transform: uppercase;
            padding: 0 20px 14px;
        }

        .sidebar-nav {
            list-style: none;
            flex: 1;
        }

        .sidebar-nav li a {
            display: flex;
            align-items: center;
            gap: 11px;
            padding: 11px 20px;
            text-decoration: none;
            font-size: .88rem;
            color: #777;
            border-left: 3px solid transparent;
            transition: background .15s, color .15s, border-color .15s;
        }

        .sidebar-nav li a:hover {
            background: rgba(255, 255, 255, .04);
            color: #ddd;
        }

        .sidebar-nav li a.active {
            border-left-color: #00CE86;
            background: rgba(0, 206, 134, .07);
            color: #00CE86;
            font-weight: 600;
        }

        .sidebar-nav li a svg {
            width: 17px;
            height: 17px;
            fill: currentColor;
            flex-shrink: 0;
        }

        .sidebar-divider {
            height: 1px;
            background: #1e1e1e;
            margin: 10px 20px;
        }

        .main-content {
            flex: 1;
            padding: 26px 26px 48px;
            overflow-y: auto;
            min-width: 0;
        }

        .page-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 16px;
        }

        .page-title {
            font-size: 1.3rem;
            font-weight: 700;
            color: #fff;
        }

        .alert {
            border-radius: 8px;
            padding: 11px 16px;
            font-size: .86rem;
            margin-bottom: 16px;
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .alert svg {
            width: 16px;
            height: 16px;
            flex-shrink: 0;
        }

        .alert-success {
            background: rgba(0, 206, 134, .1);
            border: 1px solid rgba(0, 206, 134, .3);
            color: #00CE86;
        }

        .alert-error {
            background: rgba(220, 60, 60, .1);
            border: 1px solid rgba(220, 60, 60, .3);
            color: #f08080;
        }

        .search-bar {
            background: #2b2b2b;
            border: 1px solid #333;
            border-radius: 10px;
            padding: 12px 16px;
            margin-bottom: 16px;
            display: flex;
            gap: 10px;
            align-items: center;
        }

        .search-wrap {
            flex: 1;
            position: relative;
        }

        .search-wrap svg {
            position: absolute;
            left: 12px;
            top: 50%;
            transform: translateY(-50%);
            fill: #555;
            width: 15px;
            height: 15px;
        }

        .search-input {
            width: 100%;
            background: #1e1e1e;
            border: 1px solid #3a3a3a;
            border-radius: 7px;
            color: #ddd;
            font-size: .87rem;
            padding: 9px 12px 9px 36px;
            outline: none;
            transition: border-color .2s, box-shadow .2s;
        }

        .search-input::placeholder {
            color: #4a4a4a;
        }

        .search-input:focus {
            border-color: #00CE86;
            box-shadow: 0 0 0 3px rgba(0, 206, 134, .12);
        }

        .clients-count {
            font-size: .8rem;
            color: #555;
            white-space: nowrap;
        }

        .page-grid {
            display: grid;
            grid-template-columns: 1fr 300px;
            gap: 16px;
            align-items: start;
        }

        .panel {
            background: #2b2b2b;
            border: 1px solid #333;
            border-radius: 10px;
            overflow: hidden;
        }

        .panel-header {
            padding: 13px 18px;
            border-bottom: 1px solid #333;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .panel-title {
            font-size: .9rem;
            font-weight: 700;
            color: #e8e8e8;
        }

        .panel-icon {
            fill: #00CE86;
            width: 16px;
            height: 16px;
        }

        .clients-table {
            width: 100%;
            border-collapse: collapse;
        }

        .clients-table th {
            padding: 9px 16px;
            font-size: .71rem;
            font-weight: 700;
            letter-spacing: .6px;
            text-transform: uppercase;
            color: #555;
            text-align: left;
            border-bottom: 1px solid #333;
            background: #252525;
        }

        .clients-table td {
            padding: 12px 16px;
            font-size: .87rem;
            color: #bbb;
            border-bottom: 1px solid #272727;
            vertical-align: middle;
        }

        .clients-table tr:last-child td {
            border-bottom: none;
        }

        .clients-table tr.selected td {
            background: rgba(0, 206, 134, .06);
        }

        .clients-table tr:not(.selected):hover td {
            background: rgba(255, 255, 255, .02);
            cursor: pointer;
        }

        .client-cell {
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .avatar {
            width: 32px;
            height: 32px;
            border-radius: 50%;
            background: #333;
            display: flex;
            align-items: center;
            justify-content: center;
            flex-shrink: 0;
            font-size: .74rem;
            font-weight: 700;
            color: #00CE86;
        }

        .client-name {
            font-weight: 600;
            color: #ddd;
        }

        .client-email {
            font-size: .76rem;
            color: #666;
            margin-top: 1px;
        }

        .saldo-cell {
            font-weight: 700;
        }

        .saldo-zero {
            color: #e07070;
        }

        .saldo-low {
            color: #f5a623;
        }

        .saldo-ok {
            color: #00CE86;
        }

        .btn-sel {
            background: none;
            border: 1px solid #444;
            color: #888;
            border-radius: 6px;
            padding: 6px 14px;
            font-size: .78rem;
            font-weight: 600;
            cursor: pointer;
            white-space: nowrap;
            transition: border-color .2s, color .2s, background .2s;
            text-decoration: none;
        }

        .btn-sel:hover {
            border-color: #00CE86;
            color: #00CE86;
        }

        .btn-sel.btn-sel-active {
            background: rgba(0, 206, 134, .1);
            border-color: #00CE86;
            color: #00CE86;
        }

        .saldo-panel {
            background: #262626;
            border: 1px solid #333;
            border-radius: 10px;
            overflow: hidden;
        }

        .saldo-panel-header {
            padding: 13px 16px;
            border-bottom: 1px solid #333;
        }

        .saldo-panel-title {
            font-size: .9rem;
            font-weight: 700;
            color: #e8e8e8;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .saldo-panel-title svg {
            fill: #00CE86;
            width: 16px;
            height: 16px;
        }

        .sel-client-row {
            padding: 14px 16px;
            border-bottom: 1px solid #2e2e2e;
            display: flex;
            align-items: center;
            gap: 12px;
        }

        .sel-avatar {
            width: 40px;
            height: 40px;
            border-radius: 50%;
            background: rgba(0, 206, 134, .12);
            border: 1px solid rgba(0, 206, 134, .25);
            display: flex;
            align-items: center;
            justify-content: center;
            flex-shrink: 0;
            font-size: .85rem;
            font-weight: 700;
            color: #00CE86;
        }

        .sel-name {
            font-weight: 700;
            color: #fff;
            font-size: .9rem;
        }

        .sel-email {
            font-size: .76rem;
            color: #666;
            margin-top: 2px;
        }

        .saldo-atual-row {
            padding: 12px 16px;
            border-bottom: 1px solid #2e2e2e;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .saldo-atual-label {
            font-size: .78rem;
            color: #777;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: .4px;
        }

        .saldo-atual-value {
            font-size: 1.4rem;
            font-weight: 700;
            color: #00CE86;
        }

        .saldo-action-block {
            padding: 16px;
            border-bottom: 1px solid #2a2a2a;
        }

        .saldo-action-block:last-of-type {
            border-bottom: none;
        }

        .action-block-title {
            font-size: .78rem;
            font-weight: 700;
            color: #aaa;
            text-transform: uppercase;
            letter-spacing: .5px;
            margin-bottom: 10px;
            display: flex;
            align-items: center;
            gap: 6px;
        }

        .action-block-title svg {
            width: 14px;
            height: 14px;
            fill: currentColor;
        }

        .action-block-title.add-title {
            color: #00CE86;
        }

        .action-block-title.rem-title {
            color: #e07070;
        }

        .input-group {
            display: flex;
            gap: 8px;
            align-items: center;
        }

        .saldo-input-wrap {
            position: relative;
            flex: 1;
        }

        .saldo-input-wrap .currency {
            position: absolute;
            left: 11px;
            top: 50%;
            transform: translateY(-50%);
            font-size: .85rem;
            color: #555;
            font-weight: 600;
        }

        .saldo-input {
            width: 100%;
            background: #1a1a1a;
            border: 1px solid #3a3a3a;
            border-radius: 7px;
            color: #fff;
            font-size: .92rem;
            font-weight: 700;
            padding: 9px 10px 9px 24px;
            outline: none;
            transition: border-color .2s, box-shadow .2s;
        }

        .saldo-input:focus {
            border-color: #00CE86;
            box-shadow: 0 0 0 3px rgba(0, 206, 134, .12);
        }

        .saldo-input.remove-field:focus {
            border-color: #e05555;
            box-shadow: 0 0 0 3px rgba(220, 60, 60, .1);
        }

        .btn-add {
            background: #00CE86;
            color: #111;
            border: none;
            border-radius: 7px;
            padding: 9px 16px;
            font-size: .85rem;
            font-weight: 700;
            cursor: pointer;
            white-space: nowrap;
            transition: background .2s;
            flex-shrink: 0;
        }

        .btn-add:hover {
            background: #00b876;
        }

        .btn-remove {
            background: none;
            border: 1px solid #7a3030;
            color: #e07070;
            border-radius: 7px;
            padding: 9px 16px;
            font-size: .85rem;
            font-weight: 700;
            cursor: pointer;
            white-space: nowrap;
            transition: background .2s, border-color .2s;
            flex-shrink: 0;
        }

        .btn-remove:hover {
            background: rgba(220, 60, 60, .1);
            border-color: #e05555;
        }

        .no-selection {
            padding: 40px 20px;
            text-align: center;
            color: #555;
        }

        .no-selection svg {
            fill: #2e2e2e;
            width: 44px;
            height: 44px;
            margin-bottom: 12px;
            display: block;
            margin-inline: auto;
        }

        .no-selection p {
            font-size: .85rem;
        }

        @media (max-width: 720px) {
            .page-grid {
                grid-template-columns: 1fr;
            }
        }

        @media (max-width: 580px) {
            .sidebar {
                width: 56px;
            }

            .sidebar-label, .sidebar-nav li a span {
                display: none;
            }

            .sidebar-nav li a {
                padding: 13px;
                justify-content: center;
            }

            .main-content {
                padding: 14px;
            }

            .clients-table th:nth-child(2),
            .clients-table td:nth-child(2) {
                display: none;
            }
        }
    </style>
</head>
<body>

<!-- NAV -->
<nav class="topnav">
    <a href="index.jsp" class="nav-brand">FelixUberShop</a>
    <div class="nav-right">
        <span class="nav-role">Funcionário</span>
        <div class="nav-user">
            <svg viewBox="0 0 24 24">
                <path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/>
            </svg>
            Olá, <strong style="color:#e0e0e0;margin-left:4px;"><%= funcName %>
        </strong>
        </div>
        <a href="logout.jsp" class="btn-sair">Sair</a>
    </div>
</nav>

<div class="app-shell">

    <!-- SIDEBAR -->
    <aside class="sidebar">
        <div class="sidebar-label">Área Funcionário</div>
        <ul class="sidebar-nav">
            <li><a href="funcDashboard.jsp">
                <svg viewBox="0 0 24 24">
                    <path d="M3 13h8V3H3v10zm0 8h8v-6H3v6zm10 0h8V11h-8v10zm0-18v6h8V3h-8z"/>
                </svg>
                <span>Dashboard</span></a></li>
            <li><a href="funcEncomendas.jsp">
                <svg viewBox="0 0 24 24">
                    <path d="M20 6h-2.18A3 3 0 0 0 15 4H9a3 3 0 0 0-2.82 2H4c-1.1 0-2 .9-2 2v11c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-11 0h6c.55 0 1 .45 1 1s-.45 1-1 1H9c-.55 0-1-.45-1-1s.45-1 1-1zM8 13h8v1.5H8V13zm0 3h5v1.5H8V16z"/>
                </svg>
                <span>Encomendas</span></a></li>
            <li><a href="saldoClientes.jsp" class="active">
                <svg viewBox="0 0 24 24">
                    <path d="M21 7H3c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V9c0-1.1-.9-2-2-2zm-1 12H4V9h16v10zm-5-5a2 2 0 1 1 4 0 2 2 0 0 1-4 0zM3 5h16V3H3z"/>
                </svg>
                <span>Saldo clientes</span></a></li>
            <li><a href="auditoria.jsp">
                <svg viewBox="0 0 24 24">
                    <path d="M9 17H7v-7h2v7zm4 0h-2V7h2v10zm4 0h-2v-4h2v4zm2 2H5V5h14v14zm0-16H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2z"/>
                </svg>
                <span>Auditoria</span></a></li>
            <div class="sidebar-divider"></div>
            <li><a href="funcPerfil.jsp">
                <svg viewBox="0 0 24 24">
                    <path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/>
                </svg>
                <span>Perfil</span></a></li>
        </ul>
    </aside>

    <!-- MAIN -->
    <main class="main-content">

        <div class="page-header">
            <h1 class="page-title">Clientes</h1>
        </div>

        <!-- Alerts -->
        <% if (successMsg != null && !successMsg.isEmpty()) { %>
        <div class="alert alert-success">
            <svg viewBox="0 0 24 24" fill="#00CE86">
                <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 14l-4-4 1.41-1.41L10 13.17l6.59-6.59L18 8l-8 8z"/>
            </svg>
            <%= successMsg %>
        </div>
        <% } %>
        <% if (errorMsg != null && !errorMsg.isEmpty()) { %>
        <div class="alert alert-error">
            <svg viewBox="0 0 24 24" fill="#f08080">
                <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/>
            </svg>
            <%= errorMsg %>
        </div>
        <% } %>

        <!-- Search bar -->
        <div class="search-bar">
            <div class="search-wrap">
                <svg viewBox="0 0 24 24">
                    <path d="M15.5 14h-.79l-.28-.27A6.47 6.47 0 0 0 16 9.5 6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z"/>
                </svg>
                <input type="text" id="searchInput" class="search-input"
                       placeholder="Pesquisar cliente..."
                       value="<%= filterCliente %>"
                       oninput="filterTable()"/>
            </div>
            <span class="clients-count" id="clientsCount"><%= clients.size() %> clientes</span>
        </div>

        <!-- TWO-COLUMN GRID -->
        <div class="page-grid">

            <!-- LEFT: CLIENTS TABLE -->
            <div class="panel">
                <div class="panel-header">
                    <svg class="panel-icon" viewBox="0 0 24 24">
                        <path d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z"/>
                    </svg>
                    <span class="panel-title">Clientes registados</span>
                </div>

                <table class="clients-table" id="clientsTable">
                    <thead>
                    <tr>
                        <th>Cliente</th>
                        <th>Email</th>
                        <th>Saldo</th>
                        <th>Ação</th>
                    </tr>
                    </thead>
                    <tbody>
                    <%
                        for (Object[] c : clients) {
                            String cid = (String) c[0];
                            String cname = (String) c[1];
                            String cemail = (String) c[2];
                            int csaldo = (Integer) c[3];

                            boolean isSelected = cid.equals(selectedId);

                            String saldoClass = csaldo == 0 ? "saldo-zero"
                                    : csaldo < 1000 ? "saldo-low"
                                      : "saldo-ok";

                            String saldoStr = String.format("%d,%02d €", csaldo / 100, csaldo % 100);

                            String[] pts = cname.split(" ");
                            String ini = pts.length >= 2
                                    ? "" + pts[0].charAt(0) + pts[pts.length - 1].charAt(0)
                                    : "" + pts[0].charAt(0);
                    %>
                    <tr class="<%= isSelected ? "selected" : "" %>"
                        data-name="<%= cname.toLowerCase() %>"
                        data-email="<%= cemail.toLowerCase() %>"
                        onclick="selectClient('<%= cid %>','<%= cname %>','<%= cemail %>',<%= csaldo %>)">
                        <td>
                            <div class="client-cell">
                                <div class="avatar"><%= ini %>
                                </div>
                                <div>
                                    <div class="client-name"><%= cname %>
                                    </div>
                                    <div class="client-email"><%= cemail %>
                                    </div>
                                </div>
                            </div>
                        </td>
                        <td><%= cemail %>
                        </td>
                        <td class="saldo-cell <%= saldoClass %>"><%= saldoStr %>
                        </td>
                        <td>
                            <button class="btn-sel <%= isSelected ? "btn-sel-active" : "" %>"
                                    id="selbtn-<%= cid %>"
                                    onclick="event.stopPropagation(); selectClient('<%= cid %>','<%= cname %>','<%= cemail %>',<%= csaldo %>)">
                                <%= isSelected ? "✓ Selecionado" : "Selecionar" %>
                            </button>
                        </td>
                    </tr>
                    <% } %>
                    </tbody>
                </table>
            </div>

            <!-- RIGHT: SALDO MANAGEMENT PANEL -->
            <div class="saldo-panel" id="saldoPanel">
                <div class="saldo-panel-header">
                    <div class="saldo-panel-title">
                        <svg viewBox="0 0 24 24">
                            <path d="M21 7H3c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V9c0-1.1-.9-2-2-2zm-1 12H4V9h16v10zm-5-5a2 2 0 1 1 4 0 2 2 0 0 1-4 0zM3 5h16V3H3z"/>
                        </svg>
                        Gerir saldo
                    </div>
                </div>

                <!-- Selected client info -->
                <div class="sel-client-row" id="selClientRow">
                    <div class="sel-avatar" id="selAvatar">
                        <%= selName.isEmpty() ? "?" : selName.split(" ")[0].charAt(0) + "" + (selName.split(" ").length > 1 ? selName.split(" ")[selName.split(" ").length - 1].charAt(0) : "") %>
                    </div>
                    <div>
                        <div class="sel-name"
                             id="selName"><%= selName.isEmpty() ? "Nenhum cliente selecionado" : selName %>
                        </div>
                        <div class="sel-email" id="selEmail"><%= selEmail.isEmpty() ? "" : selEmail %>
                        </div>
                    </div>
                </div>

                <!-- Current balance -->
                <div class="saldo-atual-row">
                    <span class="saldo-atual-label">Saldo atual</span>
                    <span class="saldo-atual-value" id="saldoAtual">
                            <%= String.format("%d,%02d €", selSaldo / 100, selSaldo % 100) %>
                        </span>
                </div>

                <!-- ADD saldo -->
                <div class="saldo-action-block">
                    <div class="action-block-title add-title">
                        <svg viewBox="0 0 24 24">
                            <path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z"/>
                        </svg>
                        Adicionar saldo
                    </div>
                    <form action="saldoClientes.jsp" method="post"
                          onsubmit="return confirmAction('adicionar')">
                        <input type="hidden" name="action" value="adicionar"/>
                        <input type="hidden" name="clienteId" id="addClienteId" value="<%= selectedId %>"/>
                        <div class="input-group">
                            <div class="saldo-input-wrap">
                                <span class="currency">€</span>
                                <input type="number" name="valor" id="addValor"
                                       class="saldo-input" step="0.01" min="0.01"
                                       placeholder="0,00" required/>
                            </div>
                            <button type="submit" class="btn-add">Adicionar</button>
                        </div>
                    </form>
                </div>

                <!-- REMOVE saldo -->
                <div class="saldo-action-block">
                    <div class="action-block-title rem-title">
                        <svg viewBox="0 0 24 24">
                            <path d="M19 13H5v-2h14v2z"/>
                        </svg>
                        Retirar saldo
                    </div>
                    <form action="saldoClientes.jsp" method="post"
                          onsubmit="return confirmAction('retirar')">
                        <input type="hidden" name="action" value="retirar"/>
                        <input type="hidden" name="clienteId" id="remClienteId" value="<%= selectedId %>"/>
                        <div class="input-group">
                            <div class="saldo-input-wrap">
                                <span class="currency">€</span>
                                <input type="number" name="valor" id="remValor"
                                       class="saldo-input remove-field" step="0.01" min="0.01"
                                       placeholder="0,00" required/>
                            </div>
                            <button type="submit" class="btn-remove">Retirar</button>
                        </div>
                    </form>
                </div>

            </div><!-- end saldo-panel -->

        </div><!-- end page-grid -->
    </main>
</div>

<script>
    let currentId = '<%= selectedId %>';
    let currentSaldo = <%= selSaldo %>;

    function selectClient(id, name, email, saldoCents) {

        document.getElementById('addClienteId').value = id;
        document.getElementById('remClienteId').value = id;

        const parts = name.split(' ');
        const ini = parts.length >= 2
            ? parts[0][0] + parts[parts.length - 1][0]
            : parts[0][0];
        document.getElementById('selAvatar').textContent = ini;
        document.getElementById('selName').textContent = name;
        document.getElementById('selEmail').textContent = email;

        const euros = Math.floor(saldoCents / 100);
        const cents = saldoCents % 100;
        document.getElementById('saldoAtual').textContent =
            euros + ',' + String(cents).padStart(2, '0') + ' €';

        document.querySelectorAll('.clients-table tbody tr').forEach(row => {
            row.classList.remove('selected');
        });
        document.querySelectorAll('.btn-sel').forEach(btn => {
            btn.classList.remove('btn-sel-active');
            btn.textContent = 'Selecionar';
        });

        const rows = document.querySelectorAll('.clients-table tbody tr');
        rows.forEach(row => {
            if (row.getAttribute('onclick') && row.getAttribute('onclick').includes(`'${id}'`)) {
                row.classList.add('selected');
            }
        });

        const selBtn = document.getElementById('selbtn-' + id);
        if (selBtn) {
            selBtn.classList.add('btn-sel-active');
            selBtn.textContent = '✓ Selecionado';
        }

        currentId = id;
        currentSaldo = saldoCents;

        document.getElementById('addValor').value = '';
        document.getElementById('remValor').value = '';
    }

    function confirmAction(type) {
        if (!currentId) {
            alert('Selecione um cliente primeiro.');
            return false;
        }
        const valInput = type === 'adicionar'
            ? document.getElementById('addValor')
            : document.getElementById('remValor');
        const val = parseFloat(valInput.value);
        if (!val || val <= 0) return false;

        if (type === 'retirar' && val * 100 > currentSaldo) {
            alert('Valor a retirar superior ao saldo disponível.');
            return false;
        }

        const name = document.getElementById('selName').textContent;
        const msg = type === 'adicionar'
            ? `Adicionar ${val.toFixed(2).replace('.',',')} € ao saldo de ${name}?`
            : `Retirar ${val.toFixed(2).replace('.',',')} € do saldo de ${name}?`;
        return confirm(msg);
    }

    function filterTable() {
        const q = document.getElementById('searchInput').value.toLowerCase();
        const rows = document.querySelectorAll('#clientsTable tbody tr');
        let visible = 0;
        rows.forEach(row => {
            const name = row.dataset.name || '';
            const email = row.dataset.email || '';
            const show = name.includes(q) || email.includes(q);
            row.style.display = show ? '' : 'none';
            if (show) visible++;
        });
        document.getElementById('clientsCount').textContent = visible + ' cliente' + (visible !== 1 ? 's' : '');
    }
</script>

</body>
</html>
