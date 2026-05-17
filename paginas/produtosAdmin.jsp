<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*" %>
<%@ page import="java.security.MessageDigest, java.nio.charset.StandardCharsets" %>
<%@ include file="basedados/basedados.h" %>
<%!
    private String hashPassword(String plain) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] h = md.digest(plain.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : h) sb.append(String.format("%02x", b));
            return sb.toString();
        } catch (Exception e) { throw new RuntimeException(e); }
    }
%>
<%
    HttpSession sess = request.getSession(false);
    if (sess == null || sess.getAttribute("userId") == null) { response.sendRedirect("login.jsp"); return; }
    if (!"administrador".equals(sess.getAttribute("userRole"))) { response.sendRedirect("dashboard.jsp"); return; }
    String adminName = (String) sess.getAttribute("userName");

    String successMsg = (String) sess.getAttribute("success"); if (successMsg != null) sess.removeAttribute("success");
    String errorMsg = null;

    if ("POST".equalsIgnoreCase(request.getMethod())) {
        String postAction = request.getParameter("action");

        if ("guardar".equals(postAction)) {
            String produtoId = request.getParameter("produtoId");
            String nome = request.getParameter("nome");
            String descricao = request.getParameter("descricao");
            String precoStr = request.getParameter("preco");
            String stockStr = request.getParameter("stock");
            String atoStr = request.getParameter("ativo");
            boolean ativo = "true".equalsIgnoreCase(atoStr);

            if (nome == null || nome.isBlank() || precoStr == null || precoStr.isBlank()) {
                errorMsg = "Nome e preço são obrigatórios.";
            } else {
                try {
                    double preco = Double.parseDouble(precoStr.replace(",", "."));
                    int stock = stockStr != null && !stockStr.isBlank() ? Integer.parseInt(stockStr) : 0;
                    Connection conn = getConnection();
                    if (produtoId == null || produtoId.isBlank()) {
                        PreparedStatement ps = conn.prepareStatement(
                            "INSERT INTO produtos (nome, descricao, preco, stock, ativo) VALUES (?,?,?,?,?)",
                            PreparedStatement.RETURN_GENERATED_KEYS);
                        ps.setString(1, nome.trim()); ps.setString(2, descricao);
                        ps.setDouble(3, preco); ps.setInt(4, stock); ps.setInt(5, ativo ? 1 : 0);
                        ps.executeUpdate();
                        ResultSet keys = ps.getGeneratedKeys();
                        String newId = keys.next() ? String.valueOf(keys.getInt(1)) : "";
                        closeAll(null, ps, conn);
                        sess.setAttribute("success", "Produto criado com sucesso.");
                        response.sendRedirect("produtosAdmin.jsp?produtoId=" + newId); return;
                    } else {
                        PreparedStatement ps = conn.prepareStatement(
                            "UPDATE produtos SET nome=?, descricao=?, preco=?, stock=?, ativo=? WHERE id_produto=?");
                        ps.setString(1, nome.trim()); ps.setString(2, descricao);
                        ps.setDouble(3, preco); ps.setInt(4, stock); ps.setInt(5, ativo ? 1 : 0);
                        ps.setInt(6, Integer.parseInt(produtoId));
                        ps.executeUpdate(); closeAll(null, ps, conn);
                        sess.setAttribute("success", "Produto atualizado com sucesso.");
                        response.sendRedirect("produtosAdmin.jsp?produtoId=" + produtoId); return;
                    }
                } catch (NumberFormatException e) { errorMsg = "Preço ou stock inválido."; }
                catch (Exception e) { errorMsg = "Erro: " + e.getMessage(); }
            }
        } else if ("toggleAtivo".equals(postAction)) {
            String produtoId = request.getParameter("produtoId");
            try {
                Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(
                    "UPDATE produtos SET ativo = 1 - ativo WHERE id_produto = ?");
                ps.setInt(1, Integer.parseInt(produtoId)); ps.executeUpdate(); closeAll(null, ps, conn);
                sess.setAttribute("success", "Estado do produto alterado.");
                response.sendRedirect("produtosAdmin.jsp?produtoId=" + produtoId); return;
            } catch (Exception e) { errorMsg = "Erro: " + e.getMessage(); }
        }
    }

    List<Object[]> products = new ArrayList<>();
    Connection _conn1 = null;
    PreparedStatement _ps1 = null;
    ResultSet _rs1 = null;
    try {
        _conn1 = getConnection();
        _ps1 = _conn1.prepareStatement(
            "SELECT id_produto, nome, COALESCE(descricao,''), CAST(preco*100 AS SIGNED) as preco_cents, stock, ativo " +
            "FROM produtos ORDER BY nome");
        _rs1 = _ps1.executeQuery();
        while (_rs1.next()) {
            products.add(new Object[]{
                String.valueOf(_rs1.getInt("id_produto")),
                _rs1.getString("nome"),
                _rs1.getString(3),
                (int) _rs1.getLong("preco_cents"),
                _rs1.getInt("stock"),
                _rs1.getInt("ativo") != 0
            });
        }
    } catch (Exception _e1) {
        // page renders with empty list
    } finally {
        closeAll(_rs1, _ps1, _conn1);
    }

    String selectedId = request.getParameter("produtoId") != null
            ? request.getParameter("produtoId")
            : (!products.isEmpty() ? (String) products.get(0)[0] : "");
    boolean isNovo = "true".equals(request.getParameter("novo"));

    String selNome  = "";
    String selDesc  = "";
    int    selPreco = 0;
    int    selStock = 0;
    boolean selAtivo = true;

    if (!isNovo) {
        for (Object[] p : products) {
            if (p[0].equals(selectedId)) {
                selNome  = (String)  p[1];
                selDesc  = (String)  p[2];
                selPreco = (Integer) p[3];
                selStock = (Integer) p[4];
                selAtivo = (Boolean) p[5];
                break;
            }
        }
    }

    String filterEstado = request.getParameter("estado") != null ? request.getParameter("estado") : "";
    String filterSort   = request.getParameter("sort")   != null ? request.getParameter("sort")   : "nome";
    String activePage   = "produtos";
%>
<!DOCTYPE html>
<html lang="pt">
<head>
    <meta charset="UTF-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <title>produtosAdmin</title>
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

        /* ── TOPNAV ──────────────────────────────────────── */
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
            letter-spacing: 0.4px;
        }

        .nav-right {
            display: flex;
            align-items: center;
            gap: 18px;
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

        /* ── SIDEBAR ─────────────────────────────────────── */
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

        /* ── MAIN ────────────────────────────────────────── */
        .main-content {
            flex: 1;
            padding: 26px 26px 48px;
            overflow-y: auto;
            min-width: 0;
        }

        /* ── TWO-COL LAYOUT ──────────────────────────────── */
        .page-grid {
            display: grid;
            grid-template-columns: 1fr 280px;
            gap: 16px;
            align-items: start;
        }

        /* ── LEFT PANEL ──────────────────────────────────── */
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
            justify-content: space-between;
        }

        .panel-title {
            font-size: .9rem;
            font-weight: 700;
            color: #e8e8e8;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .panel-title svg {
            fill: #00CE86;
            width: 16px;
            height: 16px;
        }

        .btn-novo {
            background: #00CE86;
            color: #111;
            border: none;
            border-radius: 7px;
            padding: 7px 14px;
            font-size: .82rem;
            font-weight: 700;
            cursor: pointer;
            text-decoration: none;
            display: inline-flex;
            align-items: center;
            gap: 5px;
            transition: background .2s;
        }

        .btn-novo:hover {
            background: #00b876;
        }

        /* Filter bar */
        .filter-bar {
            padding: 11px 16px;
            border-bottom: 1px solid #2e2e2e;
            display: flex;
            gap: 10px;
            align-items: center;
            flex-wrap: wrap;
        }

        .search-wrap {
            flex: 1;
            min-width: 140px;
            position: relative;
        }

        .search-wrap svg {
            position: absolute;
            left: 10px;
            top: 50%;
            transform: translateY(-50%);
            fill: #555;
            width: 13px;
            height: 13px;
        }

        .search-input {
            width: 100%;
            background: #1e1e1e;
            border: 1px solid #3a3a3a;
            border-radius: 7px;
            color: #ddd;
            font-size: .84rem;
            padding: 7px 10px 7px 30px;
            outline: none;
            transition: border-color .2s;
        }

        .search-input::placeholder {
            color: #4a4a4a;
        }

        .search-input:focus {
            border-color: #00CE86;
        }

        .filter-select {
            background: #1e1e1e;
            border: 1px solid #3a3a3a;
            border-radius: 7px;
            color: #ddd;
            font-size: .84rem;
            padding: 7px 10px;
            outline: none;
            cursor: pointer;
            transition: border-color .2s;
        }

        .filter-select:focus {
            border-color: #00CE86;
        }

        .filter-select option {
            background: #1e1e1e;
        }

        /* Products table */
        .products-table {
            width: 100%;
            border-collapse: collapse;
        }

        .products-table th {
            padding: 9px 14px;
            font-size: .71rem;
            font-weight: 700;
            letter-spacing: .6px;
            text-transform: uppercase;
            color: #555;
            text-align: left;
            border-bottom: 1px solid #333;
            background: #252525;
            cursor: pointer;
            user-select: none;
        }

        .products-table th:hover {
            color: #888;
        }

        .products-table th .sort-ico {
            margin-left: 3px;
            color: #00CE86;
        }

        .products-table td {
            padding: 11px 14px;
            font-size: .86rem;
            color: #bbb;
            border-bottom: 1px solid #272727;
            vertical-align: middle;
        }

        .products-table tr:last-child td {
            border-bottom: none;
        }

        .products-table tr.selected td {
            background: rgba(0, 206, 134, .05);
        }

        .products-table tr:not(.selected):hover td {
            background: rgba(255, 255, 255, .02);
            cursor: pointer;
        }

        .product-nome {
            font-weight: 600;
            color: #ddd;
        }

        .product-desc {
            color: #888;
            font-size: .82rem;
        }

        .badge {
            display: inline-block;
            padding: 3px 10px;
            border-radius: 20px;
            font-size: .71rem;
            font-weight: 700;
        }

        .badge-ativo {
            background: rgba(0, 206, 134, .12);
            color: #00CE86;
            border: 1px solid rgba(0, 206, 134, .3);
        }

        .badge-inativo {
            background: rgba(220, 60, 60, .10);
            color: #e05555;
            border: 1px solid rgba(220, 60, 60, .25);
        }

        .action-btns {
            display: flex;
            gap: 6px;
        }

        .btn-editar {
            background: none;
            border: 1px solid #444;
            color: #aaa;
            border-radius: 6px;
            padding: 4px 12px;
            font-size: .76rem;
            font-weight: 600;
            cursor: pointer;
            text-decoration: none;
            transition: border-color .2s, color .2s;
        }

        .btn-editar:hover {
            border-color: #00CE86;
            color: #00CE86;
        }

        .btn-inativar {
            background: none;
            border: 1px solid #5a2a2a;
            color: #e07070;
            border-radius: 6px;
            padding: 4px 12px;
            font-size: .76rem;
            font-weight: 600;
            cursor: pointer;
            text-decoration: none;
            transition: background .2s, border-color .2s;
        }

        .btn-inativar:hover {
            background: rgba(220, 60, 60, .1);
            border-color: #e05555;
        }

        .btn-ativar {
            background: #00CE86;
            border: none;
            color: #111;
            border-radius: 6px;
            padding: 4px 12px;
            font-size: .76rem;
            font-weight: 700;
            cursor: pointer;
            text-decoration: none;
            transition: background .2s;
        }

        .btn-ativar:hover {
            background: #00b876;
        }

        /* ── RIGHT PANEL ─────────────────────────────────── */
        .edit-panel {
            background: #262626;
            border: 1px solid #333;
            border-radius: 10px;
            overflow: hidden;
        }

        .edit-panel-header {
            padding: 13px 16px;
            border-bottom: 1px solid #333;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .edit-panel-title {
            font-size: .9rem;
            font-weight: 700;
            color: #e8e8e8;
        }

        .edit-panel-header svg {
            fill: #00CE86;
            width: 16px;
            height: 16px;
        }

        /* Alert inside panel */
        .panel-alert {
            margin: 12px 16px;
            border-radius: 7px;
            padding: 9px 13px;
            font-size: .82rem;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .panel-alert svg {
            width: 14px;
            height: 14px;
            flex-shrink: 0;
        }

        .panel-alert-success {
            background: rgba(0, 206, 134, .1);
            border: 1px solid rgba(0, 206, 134, .3);
            color: #00CE86;
        }

        .panel-alert-error {
            background: rgba(220, 60, 60, .1);
            border: 1px solid rgba(220, 60, 60, .3);
            color: #f08080;
        }

        /* Photo area — TODO: implementar upload de imagem */
        .photo-area {
            margin: 14px 16px;
            height: 110px;
            background: #1e1e1e;
            border: 2px dashed #333;
            border-radius: 9px;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            gap: 6px;
            cursor: pointer;
            transition: border-color .2s;
        }

        .photo-area:hover {
            border-color: #555;
        }

        .photo-area svg {
            fill: #444;
            width: 28px;
            height: 28px;
        }

        .photo-area span {
            font-size: .76rem;
            color: #555;
        }

        /* Form fields */
        .field-group {
            padding: 0 16px 14px;
        }

        .field-label {
            font-size: .78rem;
            color: #888;
            margin-bottom: 5px;
            display: block;
        }

        .field-input {
            width: 100%;
            background: #1a1a1a;
            border: 1px solid #3a3a3a;
            border-radius: 7px;
            color: #fff;
            font-size: .88rem;
            padding: 8px 11px;
            outline: none;
            transition: border-color .2s, box-shadow .2s;
        }

        .field-input:focus {
            border-color: #00CE86;
            box-shadow: 0 0 0 3px rgba(0, 206, 134, .1);
        }

        .fields-row {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 10px;
            padding: 0 16px 14px;
        }

        .fields-row .field-label {
            margin-bottom: 5px;
        }

        /* Action buttons */
        .edit-actions {
            padding: 0 16px 16px;
            display: flex;
            flex-direction: column;
            gap: 8px;
            border-top: 1px solid #2a2a2a;
            padding-top: 14px;
        }

        .btn-guardar {
            width: 100%;
            padding: 10px;
            background: #00CE86;
            color: #111;
            border: none;
            border-radius: 7px;
            font-size: .9rem;
            font-weight: 700;
            cursor: pointer;
            transition: background .2s;
        }

        .btn-guardar:hover {
            background: #00b876;
        }

        .btn-toggle-estado {
            width: 100%;
            padding: 10px;
            background: none;
            border: 1px solid #7a3030;
            color: #e07070;
            border-radius: 7px;
            font-size: .88rem;
            font-weight: 700;
            cursor: pointer;
            transition: background .2s, border-color .2s;
        }

        .btn-toggle-estado:hover {
            background: rgba(220, 60, 60, .1);
            border-color: #e05555;
        }

        .btn-toggle-estado.ativar {
            border-color: rgba(0, 206, 134, .4);
            color: #00CE86;
        }

        .btn-toggle-estado.ativar:hover {
            background: rgba(0, 206, 134, .08);
            border-color: #00CE86;
        }

        .no-selection {
            padding: 48px 20px;
            text-align: center;
            color: #555;
        }

        .no-selection svg {
            fill: #2e2e2e;
            width: 40px;
            height: 40px;
            margin-bottom: 12px;
            display: block;
            margin-inline: auto;
        }

        .no-selection p {
            font-size: .83rem;
        }

        /* ── RESPONSIVE ──────────────────────────────────── */
        @media (max-width: 800px) {
            .page-grid {
                grid-template-columns: 1fr;
            }
        }

        @media (max-width: 580px) {
            .sidebar {
                width: 56px;
            }

            .sidebar-label,
            .sidebar-nav li a span {
                display: none;
            }

            .sidebar-nav li a {
                padding: 13px;
                justify-content: center;
            }

            .main-content {
                padding: 14px;
            }

            .products-table th:nth-child(2),
            .products-table td:nth-child(2) {
                display: none;
            }
        }
    </style>
</head>
<body>

<!-- TOP NAV -->
<nav class="topnav">
    <a href="index.jsp" class="nav-brand">FelixUberShop</a>
    <div class="nav-right">
        <span class="nav-role">Administrador</span>
        <div class="nav-user">
            <svg viewBox="0 0 24 24">
                <path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/>
            </svg>
            Olá, <strong style="color:#e0e0e0;margin-left:4px;"><%= adminName %></strong>
        </div>
        <a href="login.jsp" class="btn-sair">Sair</a>
    </div>
</nav>

<div class="app-shell">

    <!-- SIDEBAR ADMIN -->
    <aside class="sidebar">
        <div class="sidebar-label">Área Admin</div>
        <ul class="sidebar-nav">
            <li>
                <a href="adminDashboard.jsp" class="<%= "dashboard".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24"><path d="M3 13h8V3H3v10zm0 8h8v-6H3v6zm10 0h8V11h-8v10zm0-18v6h8V3h-8z"/></svg>
                    <span>Dashboard</span>
                </a>
            </li>
            <li>
                <a href="encomendasAdmin.jsp" class="<%= "encomendas".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24"><path d="M20 6h-2.18A3 3 0 0 0 15 4H9a3 3 0 0 0-2.82 2H4c-1.1 0-2 .9-2 2v11c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-11 0h6c.55 0 1 .45 1 1s-.45 1-1 1H9c-.55 0-1-.45-1-1s.45-1 1-1zM8 13h8v1.5H8V13zm0 3h5v1.5H8V16z"/></svg>
                    <span>Encomendas</span>
                </a>
            </li>
            <li>
                <a href="saldoClientesAdmin.jsp" class="<%= "saldo".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24"><path d="M21 7H3c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V9c0-1.1-.9-2-2-2zm-1 12H4V9h16v10zm-5-5a2 2 0 1 1 4 0 2 2 0 0 1-4 0zM3 5h16V3H3z"/></svg>
                    <span>Saldo clientes</span>
                </a>
            </li>
            <li>
                <a href="produtosAdmin.jsp" class="<%= "produtos".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24"><path d="M20 2H4c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm-5 12H9v-2h6v2zm2-4H7V8h10v2z"/></svg>
                    <span>Produtos</span>
                </a>
            </li>
            <li>
                <%-- TODO: criar utilizadoresAdmin.jsp --%>
                <a href="utilizadoresAdmin.jsp" class="<%= "utilizadores".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24"><path d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z"/></svg>
                    <span>Utilizadores</span>
                </a>
            </li>
            <li>
                <%-- TODO: criar promocoesAdmin.jsp --%>
                <a href="promocoesAdmin.jsp" class="<%= "promocoes".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24"><path d="M21.41 11.58l-9-9C12.05 2.22 11.55 2 11 2H4c-1.1 0-2 .9-2 2v7c0 .55.22 1.05.59 1.42l9 9c.36.36.86.58 1.41.58.55 0 1.05-.22 1.41-.59l7-7c.37-.36.59-.86.59-1.41 0-.55-.23-1.06-.59-1.42zM5.5 7C4.67 7 4 6.33 4 5.5S4.67 4 5.5 4 7 4.67 7 5.5 6.33 7 5.5 7z"/></svg>
                    <span>Promoções</span>
                </a>
            </li>
            <li>
                <a href="auditoriaAdmin.jsp" class="<%= "auditoria".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24"><path d="M9 17H7v-7h2v7zm4 0h-2V7h2v10zm4 0h-2v-4h2v4zm2 2H5V5h14v14zm0-16H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2z"/></svg>
                    <span>Auditoria</span>
                </a>
            </li>
            <div class="sidebar-divider"></div>
            <li>
                <%-- TODO: criar perfilAdmin.jsp --%>
                <a href="perfilAdmin.jsp" class="<%= "perfil".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24"><path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/></svg>
                    <span>Perfil</span>
                </a>
            </li>
        </ul>
    </aside>

    <!-- MAIN -->
    <main class="main-content">

        <div class="page-grid">

            <!-- LEFT: PRODUCTS TABLE -->
            <div class="panel">
                <div class="panel-header">
                    <div class="panel-title">
                        <svg viewBox="0 0 24 24"><path d="M20 2H4c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm-5 12H9v-2h6v2zm2-4H7V8h10v2z"/></svg>
                        Gestão de produtos
                    </div>
                    <a href="novoProdutoAdmin.jsp" class="btn-novo">
                        <svg viewBox="0 0 24 24" style="width:13px;height:13px;fill:currentColor;"><path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z"/></svg>
                        Novo produto
                    </a>
                </div>

                <!-- Filters -->
                <div class="filter-bar">
                    <div class="search-wrap">
                        <svg viewBox="0 0 24 24"><path d="M15.5 14h-.79l-.28-.27A6.47 6.47 0 0 0 16 9.5 6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z"/></svg>
                        <input type="text" id="searchInput" class="search-input"
                               placeholder="Pesquisar produto..."
                               oninput="filterTable()"/>
                    </div>
                    <select id="filterEstado" class="filter-select" onchange="filterTable()">
                        <option value="">Todos</option>
                        <option value="ativo">Ativo</option>
                        <option value="inativo">Inativo</option>
                    </select>
                    <select id="filterSort" class="filter-select" onchange="sortTable()">
                        <option value="nome">Ordenar: Nome &#8593;</option>
                        <option value="preco">Ordenar: Preço</option>
                        <option value="stock">Ordenar: Stock</option>
                    </select>
                </div>

                <!-- Table -->
                <table class="products-table" id="productsTable">
                    <thead>
                    <tr>
                        <th>Nome &#8593;</th>
                        <th>Descrição</th>
                        <th>Preço</th>
                        <th>Stock</th>
                        <th>Estado</th>
                        <th>Ações</th>
                    </tr>
                    </thead>
                    <tbody>
                    <%
                        for (Object[] p : products) {
                            String pid    = (String)  p[0];
                            String pnome  = (String)  p[1];
                            String pdesc  = (String)  p[2];
                            int    ppreco = (Integer) p[3];
                            int    pstock = (Integer) p[4];
                            boolean pativo = (Boolean) p[5];

                            String precoStr = String.format("%d,%02d €", ppreco / 100, ppreco % 100);
                            boolean isSelected = pid.equals(selectedId) && !isNovo;
                    %>
                    <tr class="<%= isSelected ? "selected" : "" %>"
                        data-nome="<%= pnome.toLowerCase() %>"
                        data-ativo="<%= pativo ? "ativo" : "inativo" %>"
                        onclick="selectProduct('<%= pid %>','<%= pnome %>','<%= pdesc %>',<%= ppreco %>,<%= pstock %>,<%= pativo %>)">
                        <td class="product-nome"><%= pnome %></td>
                        <td class="product-desc"><%= pdesc %></td>
                        <td><%= precoStr %></td>
                        <td><%= pstock %></td>
                        <td><span class="badge <%= pativo ? "badge-ativo" : "badge-inativo" %>"><%= pativo ? "Ativo" : "Inativo" %></span></td>
                        <td onclick="event.stopPropagation()">
                            <div class="action-btns">
                                <button class="btn-editar"
                                        onclick="selectProduct('<%= pid %>','<%= pnome %>','<%= pdesc %>',<%= ppreco %>,<%= pstock %>,<%= pativo %>)">
                                    Editar
                                </button>
                                <form method="post" action="produtosAdmin.jsp" style="display:inline;margin:0">
                                    <input type="hidden" name="action" value="toggleAtivo"/>
                                    <input type="hidden" name="produtoId" value="<%= pid %>"/>
                                    <button type="submit" class="<%= pativo ? "btn-inativar" : "btn-ativar" %>"
                                            onclick="return confirm('<%= pativo ? "Inativar" : "Ativar" %> <%= pnome %>?')">
                                        <%= pativo ? "Inativar" : "Ativar" %>
                                    </button>
                                </form>
                            </div>
                        </td>
                    </tr>
                    <% } %>
                    </tbody>
                </table>
            </div>

            <!-- RIGHT: EDIT PANEL -->
            <div class="edit-panel">
                <div class="edit-panel-header">
                    <svg viewBox="0 0 24 24"><path d="M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25zM20.71 7.04a1 1 0 0 0 0-1.41l-2.34-2.34a1 1 0 0 0-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83z"/></svg>
                    <span class="edit-panel-title" id="editPanelTitle">Editar produto</span>
                </div>

                <!-- Alert -->
                <% if (successMsg != null && !successMsg.isEmpty()) { %>
                <div class="panel-alert panel-alert-success">
                    <svg viewBox="0 0 24 24" fill="#00CE86"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 14l-4-4 1.41-1.41L10 13.17l6.59-6.59L18 8l-8 8z"/></svg>
                    <%= successMsg %>
                </div>
                <% } %>
                <% if (errorMsg != null && !errorMsg.isEmpty()) { %>
                <div class="panel-alert panel-alert-error">
                    <svg viewBox="0 0 24 24" fill="#f08080"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/></svg>
                    <%= errorMsg %>
                </div>
                <% } %>

                <div id="editFormArea">
                    <% if (!isNovo && selNome.isEmpty()) { %>
                    <!-- No product selected -->
                    <div class="no-selection">
                        <svg viewBox="0 0 24 24"><path d="M20 2H4c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm-5 12H9v-2h6v2zm2-4H7V8h10v2z"/></svg>
                        <p>Seleciona um produto para editar</p>
                    </div>
                    <% } else { %>

                    <!-- Photo area — TODO: implementar upload de imagem do produto -->
                    <div class="photo-area" onclick="alert('TODO: upload de imagem')">
                        <svg viewBox="0 0 24 24"><path d="M12 15.2A3.2 3.2 0 1 1 12 8.8a3.2 3.2 0 0 1 0 6.4zm0-8.2a5 5 0 1 0 0 10A5 5 0 0 0 12 7zM4 5h2.17L7.4 3.6A1 1 0 0 1 8.26 3h7.48a1 1 0 0 1 .86.6L17.83 5H20a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2z"/></svg>
                        <span>Clica para adicionar foto</span>
                    </div>

                    <form action="produtosAdmin.jsp" method="post"
                          onsubmit="return confirm('Guardar alterações?')">
                        <input type="hidden" name="action" value="guardar"/>
                        <input type="hidden" id="hiddenId" name="produtoId" value="<%= isNovo ? "" : selectedId %>"/>
                        <input type="hidden" id="hiddenAtivo" name="ativo" value="<%= selAtivo %>"/>

                        <div class="field-group">
                            <label class="field-label">Nome</label>
                            <input type="text" name="nome" id="fieldNome"
                                   class="field-input"
                                   value="<%= selNome %>"
                                   placeholder="Nome do produto" required/>
                        </div>

                        <div class="field-group">
                            <label class="field-label">Descrição</label>
                            <input type="text" name="descricao" id="fieldDesc"
                                   class="field-input"
                                   value="<%= selDesc %>"
                                   placeholder="Descrição breve"/>
                        </div>

                        <div class="fields-row">
                            <div>
                                <label class="field-label">Preço (&euro;)</label>
                                <%
                                    String precoValStr = selPreco > 0
                                        ? String.format("%d.%02d", selPreco / 100, selPreco % 100)
                                        : "";
                                %>
                                <input type="number" name="preco" id="fieldPreco"
                                       class="field-input"
                                       value="<%= precoValStr %>"
                                       step="0.01" min="0" placeholder="0,00" required/>
                            </div>
                            <div>
                                <label class="field-label">Stock</label>
                                <input type="number" name="stock" id="fieldStock"
                                       class="field-input"
                                       value="<%= isNovo ? "" : selStock %>"
                                       min="0" placeholder="0" required/>
                            </div>
                        </div>

                        <div class="edit-actions">
                            <button type="submit" class="btn-guardar">Guardar alterações</button>
                        </div>
                    </form>
                    <% if (!isNovo && !selNome.isEmpty()) { %>
                    <div style="padding: 0 16px 16px;">
                        <form method="post" action="produtosAdmin.jsp" style="margin:0"
                              onsubmit="return confirm('<%= selAtivo ? "Inativar" : "Ativar" %> produto?')">
                            <input type="hidden" name="action" value="toggleAtivo"/>
                            <input type="hidden" name="produtoId" value="<%= selectedId %>"/>
                            <button type="submit" id="btnToggleEstado"
                                    class="btn-toggle-estado <%= selAtivo ? "" : "ativar" %>">
                                <%= selAtivo ? "Inativar produto" : "Ativar produto" %>
                            </button>
                        </form>
                    </div>
                    <% } %>
                    <% } %>
                </div>

            </div><!-- end edit-panel -->

        </div><!-- end page-grid -->
    </main>
</div>

<script>
    let currentAtivo = <%= selAtivo %>;

    function selectProduct(id, nome, desc, precoCents, stock, ativo) {
        document.getElementById('editPanelTitle').textContent = 'Editar produto';
        document.getElementById('hiddenId').value    = id;
        document.getElementById('hiddenAtivo').value = ativo;
        document.getElementById('fieldNome').value   = nome;
        document.getElementById('fieldDesc').value   = desc;

        const euros = Math.floor(precoCents / 100);
        const cents = precoCents % 100;
        document.getElementById('fieldPreco').value  = euros + '.' + String(cents).padStart(2, '0');
        document.getElementById('fieldStock').value  = stock;

        const btn = document.getElementById('btnToggleEstado');
        if (btn) {
            if (ativo) {
                btn.textContent = 'Inativar produto';
                btn.classList.remove('ativar');
                btn.onclick = () => confirm('Inativar ' + nome + '?');
            } else {
                btn.textContent = 'Ativar produto';
                btn.classList.add('ativar');
                btn.onclick = () => confirm('Ativar ' + nome + '?');
            }
        }

        document.querySelectorAll('.products-table tbody tr').forEach(row => row.classList.remove('selected'));
        document.querySelectorAll('.products-table tbody tr').forEach(row => {
            if (row.dataset.nome === nome.toLowerCase()) row.classList.add('selected');
        });

        currentAtivo = ativo;
    }

    function novoMode() {
        document.getElementById('editPanelTitle').textContent = 'Novo produto';
        document.getElementById('hiddenId').value    = '';
        document.getElementById('hiddenAtivo').value = 'true';
        document.getElementById('fieldNome').value   = '';
        document.getElementById('fieldDesc').value   = '';
        document.getElementById('fieldPreco').value  = '';
        document.getElementById('fieldStock').value  = '';

        const btn = document.getElementById('btnToggleEstado');
        if (btn) btn.style.display = 'none';

        document.querySelectorAll('.products-table tbody tr').forEach(row => row.classList.remove('selected'));
    }

    function filterTable() {
        const q      = document.getElementById('searchInput').value.toLowerCase();
        const estado = document.getElementById('filterEstado').value;
        const rows   = document.querySelectorAll('#productsTable tbody tr');
        rows.forEach(row => {
            const nome  = row.dataset.nome  || '';
            const ativo = row.dataset.ativo || '';
            const matchQ = nome.includes(q);
            const matchE = !estado || ativo === estado;
            row.style.display = (matchQ && matchE) ? '' : 'none';
        });
    }

    function sortTable() {
        /* TODO: ordenação server-side ou client-side */
    }
</script>

</body>
</html>

