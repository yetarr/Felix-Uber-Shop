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
    String activePage = "promocoes";

    String successMsg = (String) sess.getAttribute("success"); if (successMsg != null) sess.removeAttribute("success");
    String errorMsg = null;

    if ("POST".equalsIgnoreCase(request.getMethod())) {
        String postAction = request.getParameter("action");

        if ("guardar".equals(postAction)) {
            String promoId = request.getParameter("promoId");
            String titulo = request.getParameter("titulo");
            String descontoStr = request.getParameter("desconto");
            String dataInicio = request.getParameter("dataInicio");
            String dataFim = request.getParameter("dataFim");
            boolean ativo = "true".equalsIgnoreCase(request.getParameter("ativo"));
            String[] produtosIds = request.getParameterValues("produtos");

            if (titulo == null || titulo.isBlank() || descontoStr == null || dataInicio == null || dataFim == null) {
                errorMsg = "Todos os campos são obrigatórios.";
            } else {
                try {
                    double desconto = Double.parseDouble(descontoStr.replace(",", "."));
                    Connection conn = getConnection();
                    int savedId;
                    if (promoId == null || promoId.isBlank()) {
                        PreparedStatement ps = conn.prepareStatement(
                            "INSERT INTO promocoes (titulo, desconto_percentagem, data_inicio, data_fim, ativo) VALUES (?,?,?,?,?)",
                            PreparedStatement.RETURN_GENERATED_KEYS);
                        ps.setString(1, titulo.trim()); ps.setDouble(2, desconto);
                        ps.setString(3, dataInicio); ps.setString(4, dataFim); ps.setInt(5, ativo ? 1 : 0);
                        ps.executeUpdate();
                        ResultSet keys = ps.getGeneratedKeys(); savedId = keys.next() ? keys.getInt(1) : -1; keys.close(); ps.close();
                    } else {
                        savedId = Integer.parseInt(promoId);
                        PreparedStatement ps = conn.prepareStatement(
                            "UPDATE promocoes SET titulo=?, desconto_percentagem=?, data_inicio=?, data_fim=?, ativo=? WHERE id_promocao=?");
                        ps.setString(1, titulo.trim()); ps.setDouble(2, desconto);
                        ps.setString(3, dataInicio); ps.setString(4, dataFim);
                        ps.setInt(5, ativo ? 1 : 0); ps.setInt(6, savedId);
                        ps.executeUpdate(); ps.close();
                    }
                    PreparedStatement ps = conn.prepareStatement("DELETE FROM promocao_produto WHERE id_promocao = ?");
                    ps.setInt(1, savedId); ps.executeUpdate(); ps.close();
                    if (produtosIds != null) {
                        ps = conn.prepareStatement("INSERT INTO promocao_produto (id_promocao, id_produto) VALUES (?,?)");
                        for (String pid : produtosIds) {
                            ps.setInt(1, savedId); ps.setInt(2, Integer.parseInt(pid)); ps.executeUpdate();
                        }
                        ps.close();
                    }
                    conn.close();
                    sess.setAttribute("success", "Promoção guardada com sucesso.");
                    response.sendRedirect("promocoesAdmin.jsp?promoId=" + savedId); return;
                } catch (NumberFormatException e) { errorMsg = "Desconto inválido."; }
                catch (Exception e) { errorMsg = "Erro: " + e.getMessage(); }
            }
        } else if ("toggleAtivo".equals(postAction)) {
            String pid = request.getParameter("promoId");
            try {
                Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement("UPDATE promocoes SET ativo = 1 - ativo WHERE id_promocao = ?");
                ps.setInt(1, Integer.parseInt(pid)); ps.executeUpdate(); closeAll(null, ps, conn);
                sess.setAttribute("success", "Estado da promoção alterado.");
                response.sendRedirect("promocoesAdmin.jsp?promoId=" + pid); return;
            } catch (Exception e) { errorMsg = "Erro: " + e.getMessage(); }
        }
    }

    List<Object[]> promos = new ArrayList<>();
    List<Object[]> catalogue = new ArrayList<>();
    Connection _conn2 = null;
    PreparedStatement _ps2 = null;
    ResultSet _rs2 = null;
    try {
        _conn2 = getConnection();
        // Load promos
        _ps2 = _conn2.prepareStatement(
            "SELECT id_promocao, titulo, desconto_percentagem, data_inicio, data_fim, ativo " +
            "FROM promocoes ORDER BY id_promocao");
        _rs2 = _ps2.executeQuery();
        while (_rs2.next()) {
            promos.add(new Object[]{
                String.valueOf(_rs2.getInt("id_promocao")),
                _rs2.getString("titulo"),
                _rs2.getBigDecimal("desconto_percentagem").intValue(),
                _rs2.getString("data_inicio"),
                _rs2.getString("data_fim"),
                _rs2.getInt("ativo") != 0
            });
        }
        closeAll(_rs2, _ps2, null);
        // Load catalogue
        _ps2 = _conn2.prepareStatement(
            "SELECT id_produto, nome, CAST(preco*100 AS SIGNED) as preco_cents " +
            "FROM produtos WHERE ativo=1 ORDER BY nome");
        _rs2 = _ps2.executeQuery();
        while (_rs2.next()) {
            catalogue.add(new Object[]{
                String.valueOf(_rs2.getInt("id_produto")),
                _rs2.getString("nome"),
                (int) _rs2.getLong("preco_cents")
            });
        }
    } catch (Exception _e2) {
        // page renders with empty lists
    } finally {
        closeAll(_rs2, _ps2, _conn2);
    }

    String selectedId = request.getParameter("promoId") != null
            ? request.getParameter("promoId")
            : (!promos.isEmpty() ? (String) promos.get(0)[0] : "");

    String  selTitulo   = "";
    int     selDesconto = 0;
    String  selInicio   = "";
    String  selFim      = "";
    boolean selAtivo    = true;

    for (Object[] p : promos) {
        if (p[0].equals(selectedId)) {
            selTitulo   = (String)  p[1];
            selDesconto = (Integer) p[2];
            selInicio   = (String)  p[3];
            selFim      = (String)  p[4];
            selAtivo    = (Boolean) p[5];
            break;
        }
    }

    // Load product ids for selected promo
    Set<String> selProds = new HashSet<>();
    if (!selectedId.isEmpty()) {
        Connection _conn2b = null;
        PreparedStatement _ps2b = null;
        ResultSet _rs2b = null;
        try {
            _conn2b = getConnection();
            _ps2b = _conn2b.prepareStatement(
                "SELECT id_produto FROM promocao_produto WHERE id_promocao = ?");
            _ps2b.setInt(1, Integer.parseInt(selectedId));
            _rs2b = _ps2b.executeQuery();
            while (_rs2b.next()) {
                selProds.add(String.valueOf(_rs2b.getInt("id_produto")));
            }
        } catch (Exception _e2b) {
            // empty selProds on error
        } finally {
            closeAll(_rs2b, _ps2b, _conn2b);
        }
    }
%>
<!DOCTYPE html>
<html lang="pt">
<head>
    <meta charset="UTF-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <title>promocoesAdmin</title>
    <style>
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

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

        .nav-brand { font-size: 1.2rem; font-weight: 700; color: #00CE86; text-decoration: none; letter-spacing: .4px; }

        .nav-right { display: flex; align-items: center; gap: 18px; }

        .nav-role {
            font-size: .68rem; font-weight: 700; letter-spacing: .6px;
            background: rgba(0,206,134,.12); color: #00CE86;
            border: 1px solid rgba(0,206,134,.25); padding: 2px 8px;
            border-radius: 20px; text-transform: uppercase;
        }

        .nav-user { display: flex; align-items: center; gap: 8px; font-size: .87rem; color: #bbb; }
        .nav-user svg { fill: #00CE86; width: 20px; height: 20px; }

        .btn-sair {
            background: none; border: 1px solid #555; color: #aaa;
            font-size: .8rem; padding: 5px 14px; border-radius: 6px;
            cursor: pointer; text-decoration: none; transition: border-color .2s, color .2s;
        }
        .btn-sair:hover { border-color: #e05555; color: #e05555; }

        .app-shell { display: flex; flex: 1; min-height: 0; }

        /* ── SIDEBAR ─────────────────────────────────────── */
        .sidebar {
            width: 215px; flex-shrink: 0; background: #111;
            border-right: 1px solid #1e1e1e;
            display: flex; flex-direction: column; padding: 24px 0 16px;
        }

        .sidebar-label {
            font-size: .67rem; font-weight: 700; letter-spacing: 1.2px;
            color: #3a3a3a; text-transform: uppercase; padding: 0 20px 14px;
        }

        .sidebar-nav { list-style: none; flex: 1; }

        .sidebar-nav li a {
            display: flex; align-items: center; gap: 11px;
            padding: 11px 20px; text-decoration: none;
            font-size: .88rem; color: #777;
            border-left: 3px solid transparent;
            transition: background .15s, color .15s, border-color .15s;
        }
        .sidebar-nav li a:hover { background: rgba(255,255,255,.04); color: #ddd; }
        .sidebar-nav li a.active {
            border-left-color: #00CE86; background: rgba(0,206,134,.07);
            color: #00CE86; font-weight: 600;
        }
        .sidebar-nav li a svg { width: 17px; height: 17px; fill: currentColor; flex-shrink: 0; }

        .sidebar-divider { height: 1px; background: #1e1e1e; margin: 10px 20px; }

        /* ── MAIN ────────────────────────────────────────── */
        .main-content { flex: 1; padding: 26px 26px 48px; overflow-y: auto; min-width: 0; }

        .page-grid {
            display: grid;
            grid-template-columns: 1fr 280px;
            gap: 16px;
            align-items: start;
        }

        /* ── LEFT PANEL ──────────────────────────────────── */
        .panel { background: #2b2b2b; border: 1px solid #333; border-radius: 10px; overflow: hidden; }

        .panel-header {
            padding: 13px 18px; border-bottom: 1px solid #333;
            display: flex; align-items: center; justify-content: space-between;
        }

        .panel-title {
            font-size: .9rem; font-weight: 700; color: #e8e8e8;
            display: flex; align-items: center; gap: 8px;
        }
        .panel-title svg { fill: #00CE86; width: 16px; height: 16px; }

        .btn-novo {
            background: #00CE86; color: #111; border: none; border-radius: 7px;
            padding: 7px 14px; font-size: .82rem; font-weight: 700; cursor: pointer;
            text-decoration: none; display: inline-flex; align-items: center; gap: 5px;
            transition: background .2s;
        }
        .btn-novo:hover { background: #00b876; }

        /* Filter bar */
        .filter-bar {
            padding: 11px 16px; border-bottom: 1px solid #2e2e2e;
            display: flex; gap: 10px; align-items: center;
        }

        .search-wrap { flex: 1; position: relative; }
        .search-wrap svg {
            position: absolute; left: 10px; top: 50%; transform: translateY(-50%);
            fill: #555; width: 13px; height: 13px;
        }

        .search-input {
            width: 100%; background: #1e1e1e; border: 1px solid #3a3a3a;
            border-radius: 7px; color: #ddd; font-size: .84rem;
            padding: 7px 10px 7px 30px; outline: none; transition: border-color .2s;
        }
        .search-input::placeholder { color: #4a4a4a; }
        .search-input:focus { border-color: #00CE86; }

        .filter-select {
            background: #1e1e1e; border: 1px solid #3a3a3a; border-radius: 7px;
            color: #ddd; font-size: .84rem; padding: 7px 10px;
            outline: none; cursor: pointer; transition: border-color .2s;
        }
        .filter-select:focus { border-color: #00CE86; }
        .filter-select option { background: #1e1e1e; }

        /* Table */
        .promos-table { width: 100%; border-collapse: collapse; }

        .promos-table th {
            padding: 9px 14px; font-size: .71rem; font-weight: 700;
            letter-spacing: .6px; text-transform: uppercase; color: #555;
            text-align: left; border-bottom: 1px solid #333; background: #252525;
        }

        .promos-table td {
            padding: 11px 14px; font-size: .86rem; color: #bbb;
            border-bottom: 1px solid #272727; vertical-align: middle;
        }
        .promos-table tr:last-child td { border-bottom: none; }
        .promos-table tr.selected td { background: rgba(0,206,134,.05); }
        .promos-table tr:not(.selected):hover td {
            background: rgba(255,255,255,.02); cursor: pointer;
        }

        .promo-titulo { font-weight: 600; color: #ddd; }
        .desconto-val { color: #00CE86; font-weight: 600; }

        .badge {
            display: inline-block; padding: 3px 10px;
            border-radius: 20px; font-size: .71rem; font-weight: 700;
        }
        .badge-ativo  { background: rgba(0,206,134,.12); color: #00CE86; border: 1px solid rgba(0,206,134,.3); }
        .badge-inativo{ background: rgba(220,60,60,.10); color: #e05555; border: 1px solid rgba(220,60,60,.25); }

        .action-btns { display: flex; gap: 6px; }

        .btn-editar {
            background: none; border: 1px solid #444; color: #aaa;
            border-radius: 6px; padding: 4px 12px; font-size: .76rem; font-weight: 600;
            cursor: pointer; transition: border-color .2s, color .2s;
        }
        .btn-editar:hover { border-color: #00CE86; color: #00CE86; }

        .btn-inativar {
            background: none; border: 1px solid #5a2a2a; color: #e07070;
            border-radius: 6px; padding: 4px 12px; font-size: .76rem; font-weight: 600;
            cursor: pointer; transition: background .2s, border-color .2s;
        }
        .btn-inativar:hover { background: rgba(220,60,60,.1); border-color: #e05555; }

        .btn-ativar {
            background: #00CE86; border: none; color: #111;
            border-radius: 6px; padding: 4px 12px; font-size: .76rem; font-weight: 700;
            cursor: pointer; transition: background .2s;
        }
        .btn-ativar:hover { background: #00b876; }

        /* ── RIGHT PANEL ─────────────────────────────────── */
        .edit-panel { background: #262626; border: 1px solid #333; border-radius: 10px; overflow: hidden; }

        .edit-panel-header {
            padding: 13px 16px; border-bottom: 1px solid #333;
            display: flex; align-items: center; gap: 8px;
        }
        .edit-panel-title { font-size: .9rem; font-weight: 700; color: #e8e8e8; }
        .edit-panel-header svg { fill: #00CE86; width: 16px; height: 16px; }

        .panel-alert {
            margin: 12px 16px 0; border-radius: 7px; padding: 9px 13px;
            font-size: .82rem; display: flex; align-items: center; gap: 8px;
        }
        .panel-alert svg { width: 14px; height: 14px; flex-shrink: 0; }
        .panel-alert-success {
            background: rgba(0,206,134,.1); border: 1px solid rgba(0,206,134,.3); color: #00CE86;
        }
        .panel-alert-error {
            background: rgba(220,60,60,.1); border: 1px solid rgba(220,60,60,.3); color: #f08080;
        }

        .form-top-gap { height: 14px; }

        .field-group { padding: 0 16px 12px; }

        .field-label { font-size: .78rem; color: #888; margin-bottom: 5px; display: block; }

        .field-input {
            width: 100%; background: #1a1a1a; border: 1px solid #3a3a3a;
            border-radius: 7px; color: #fff; font-size: .88rem;
            padding: 8px 11px; outline: none; font-family: inherit;
            transition: border-color .2s, box-shadow .2s;
        }
        .field-input:focus { border-color: #00CE86; box-shadow: 0 0 0 3px rgba(0,206,134,.1); }

        .fields-row { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; padding: 0 16px 12px; }
        .fields-row .field-label { margin-bottom: 5px; }

        /* Produto checkboxes */
        .prods-label { font-size: .78rem; color: #888; padding: 0 16px 8px; display: block; }

        .prod-list { margin: 0 16px 14px; border: 1px solid #2e2e2e; border-radius: 8px; overflow: hidden; }

        .prod-item {
            display: flex; align-items: center; justify-content: space-between;
            padding: 9px 12px; border-bottom: 1px solid #242424;
            cursor: pointer; transition: background .15s;
        }
        .prod-item:last-child { border-bottom: none; }
        .prod-item:hover { background: rgba(255,255,255,.03); }

        .prod-item-left { display: flex; align-items: center; gap: 9px; }

        .prod-item input[type="checkbox"] {
            accent-color: #00CE86; width: 15px; height: 15px; cursor: pointer; flex-shrink: 0;
        }

        .prod-item-nome { font-size: .84rem; color: #ccc; }
        .prod-item-preco { font-size: .82rem; color: #666; }

        /* Botões de acção */
        .edit-actions {
            padding: 0 16px 16px; display: flex; flex-direction: column; gap: 8px;
            border-top: 1px solid #2a2a2a; padding-top: 14px;
        }

        .btn-guardar {
            width: 100%; padding: 10px; background: #00CE86; color: #111;
            border: none; border-radius: 7px; font-size: .9rem; font-weight: 700;
            cursor: pointer; transition: background .2s;
        }
        .btn-guardar:hover { background: #00b876; }

        .btn-toggle-estado {
            width: 100%; padding: 10px; background: rgba(180,30,30,.15);
            border: 1px solid #7a3030; color: #e07070;
            border-radius: 7px; font-size: .88rem; font-weight: 700;
            cursor: pointer; transition: background .2s, border-color .2s;
        }
        .btn-toggle-estado:hover { background: rgba(220,60,60,.18); border-color: #e05555; }
        .btn-toggle-estado.ativar { border-color: rgba(0,206,134,.4); color: #00CE86; background: none; }
        .btn-toggle-estado.ativar:hover { background: rgba(0,206,134,.08); border-color: #00CE86; }

        /* Responsive */
        @media (max-width: 800px) { .page-grid { grid-template-columns: 1fr; } }

        @media (max-width: 580px) {
            .sidebar { width: 56px; }
            .sidebar-label, .sidebar-nav li a span { display: none; }
            .sidebar-nav li a { padding: 13px; justify-content: center; }
            .main-content { padding: 14px; }
            .promos-table th:nth-child(3), .promos-table td:nth-child(3),
            .promos-table th:nth-child(4), .promos-table td:nth-child(4) { display: none; }
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
            <svg viewBox="0 0 24 24"><path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/></svg>
            Olá, <strong style="color:#e0e0e0;margin-left:4px;"><%= adminName %></strong>
        </div>
        <a href="login.jsp" class="btn-sair">Sair</a>
    </div>
</nav>

<div class="app-shell">

    <!-- SIDEBAR -->
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
                <a href="utilizadoresAdmin.jsp" class="<%= "utilizadores".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24"><path d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z"/></svg>
                    <span>Utilizadores</span>
                </a>
            </li>
            <li>
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

            <!-- LEFT: TABLE -->
            <div class="panel">
                <div class="panel-header">
                    <div class="panel-title">
                        <svg viewBox="0 0 24 24"><path d="M21.41 11.58l-9-9C12.05 2.22 11.55 2 11 2H4c-1.1 0-2 .9-2 2v7c0 .55.22 1.05.59 1.42l9 9c.36.36.86.58 1.41.58.55 0 1.05-.22 1.41-.59l7-7c.37-.36.59-.86.59-1.41 0-.55-.23-1.06-.59-1.42zM5.5 7C4.67 7 4 6.33 4 5.5S4.67 4 5.5 4 7 4.67 7 5.5 6.33 7 5.5 7z"/></svg>
                        Gestão de promoções
                    </div>
                    <%-- TODO: criar novaPromocaoAdmin.jsp --%>
                    <a href="novaPromocaoAdmin.jsp" class="btn-novo">
                        <svg viewBox="0 0 24 24" style="width:13px;height:13px;fill:currentColor;"><path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z"/></svg>
                        Nova promoção
                    </a>
                </div>

                <div class="filter-bar">
                    <div class="search-wrap">
                        <svg viewBox="0 0 24 24"><path d="M15.5 14h-.79l-.28-.27A6.47 6.47 0 0 0 16 9.5 6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z"/></svg>
                        <input type="text" id="searchInput" class="search-input"
                               placeholder="Pesquisar..." oninput="filterTable()"/>
                    </div>
                    <select id="filterEstado" class="filter-select" onchange="filterTable()">
                        <option value="">Todas</option>
                        <option value="ativo">Ativas</option>
                        <option value="inativo">Inativas</option>
                    </select>
                </div>

                <table class="promos-table" id="promosTable">
                    <thead>
                    <tr>
                        <th>Título</th>
                        <th>Desconto</th>
                        <th>Início</th>
                        <th>Fim</th>
                        <th>Produtos</th>
                        <th>Estado</th>
                        <th>Ações</th>
                    </tr>
                    </thead>
                    <tbody>
                    <%
                        for (Object[] pr : promos) {
                            String  pid      = (String)  pr[0];
                            String  ptitulo  = (String)  pr[1];
                            int     pdesc    = (Integer) pr[2];
                            String  pinicio  = (String)  pr[3];
                            String  pfim     = (String)  pr[4];
                            boolean pativo   = (Boolean) pr[5];

                            // DD/MM/YYYY display
                            String inicioDisplay = (pinicio != null && pinicio.length() >= 10)
                                ? pinicio.substring(8) + "/" + pinicio.substring(5,7) + "/" + pinicio.substring(0,4)
                                : (pinicio != null ? pinicio : "");
                            String fimDisplay = (pfim != null && pfim.length() >= 10)
                                ? pfim.substring(8) + "/" + pfim.substring(5,7) + "/" + pfim.substring(0,4)
                                : (pfim != null ? pfim : "");

                            boolean isSel = pid.equals(selectedId);
                    %>
                    <tr class="<%= isSel ? "selected" : "" %>"
                        data-titulo="<%= ptitulo.toLowerCase() %>"
                        data-ativo="<%= pativo ? "ativo" : "inativo" %>"
                        onclick="selectPromo('<%= pid %>')">
                        <td class="promo-titulo"><%= ptitulo %></td>
                        <td class="desconto-val"><%= pdesc %>%</td>
                        <td><%= inicioDisplay %></td>
                        <td><%= fimDisplay %></td>
                        <td>—</td>
                        <td><span class="badge <%= pativo ? "badge-ativo" : "badge-inativo" %>"><%= pativo ? "Ativo" : "Inativo" %></span></td>
                        <td onclick="event.stopPropagation()">
                            <div class="action-btns">
                                <button class="btn-editar" onclick="selectPromo('<%= pid %>')">Editar</button>
                                <form method="post" action="promocoesAdmin.jsp" style="display:inline;margin:0">
                                    <input type="hidden" name="action" value="toggleAtivo"/>
                                    <input type="hidden" name="promoId" value="<%= pid %>"/>
                                    <button type="submit" class="<%= pativo ? "btn-inativar" : "btn-ativar" %>"
                                            onclick="return confirm('<%= pativo ? "Inativar" : "Ativar" %> <%= ptitulo %>?')">
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
                    <span class="edit-panel-title">Editar promoção</span>
                </div>

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

                <form action="promocoesAdmin.jsp" method="post">
                    <input type="hidden" name="action"   value="guardar"/>
                    <input type="hidden" id="hiddenId"   name="promoId" value="<%= selectedId %>"/>
                    <input type="hidden" id="hiddenAtivo" name="ativo"  value="<%= selAtivo %>"/>

                    <div class="form-top-gap"></div>

                    <div class="field-group">
                        <label class="field-label">Título</label>
                        <input type="text" name="titulo" id="fieldTitulo"
                               class="field-input" value="<%= selTitulo %>" required/>
                    </div>

                    <div class="field-group">
                        <label class="field-label">Desconto (%)</label>
                        <input type="number" name="desconto" id="fieldDesconto"
                               class="field-input" value="<%= selDesconto %>"
                               min="1" max="100" required/>
                    </div>

                    <div class="fields-row">
                        <div>
                            <label class="field-label">Data início</label>
                            <input type="date" name="dataInicio" id="fieldInicio"
                                   class="field-input" value="<%= selInicio %>" required/>
                        </div>
                        <div>
                            <label class="field-label">Data fim</label>
                            <input type="date" name="dataFim" id="fieldFim"
                                   class="field-input" value="<%= selFim %>" required/>
                        </div>
                    </div>

                    <span class="prods-label">Produtos associados</span>
                    <div class="prod-list">
                        <%
                            for (Object[] cat : catalogue) {
                                String  catId    = (String)  cat[0];
                                String  catNome  = (String)  cat[1];
                                int     catPreco = (Integer) cat[2];
                                boolean checked  = selProds.contains(catId);
                        %>
                        <label class="prod-item">
                            <div class="prod-item-left">
                                <input type="checkbox" name="produtos"
                                       id="chk_<%= catId %>" value="<%= catId %>"
                                       <%= checked ? "checked" : "" %>/>
                                <span class="prod-item-nome"><%= catNome %></span>
                            </div>
                            <span class="prod-item-preco">
                                <%= String.format("%d,%02d &euro;", catPreco / 100, catPreco % 100) %>
                            </span>
                        </label>
                        <% } %>
                    </div>

                    <div class="edit-actions">
                        <button type="submit" class="btn-guardar">Guardar alterações</button>
                    </div>
                </form>
                <% if (!selectedId.isEmpty()) { %>
                <div style="padding: 0 16px 16px;">
                    <form method="post" action="promocoesAdmin.jsp" style="margin:0"
                          onsubmit="return confirm('<%= selAtivo ? "Inativar" : "Ativar" %> promoção?')">
                        <input type="hidden" name="action" value="toggleAtivo"/>
                        <input type="hidden" name="promoId" value="<%= selectedId %>"/>
                        <button type="submit" id="btnToggle"
                                class="btn-toggle-estado <%= selAtivo ? "" : "ativar" %>">
                            <%= selAtivo ? "Inativar promoção" : "Ativar promoção" %>
                        </button>
                    </form>
                </div>
                <% } %>
            </div>

        </div>
    </main>
</div>

<script>
    /* Promo data mirrored from JSP for client-side panel updates */
    var promoData = {
        <%
            boolean first = true;
            for (Object[] pr : promos) {
                String  pid      = (String)  pr[0];
                String  ptitulo  = (String)  pr[1];
                int     pdesc    = (Integer) pr[2];
                String  pinicio  = (String)  pr[3];
                String  pfim     = (String)  pr[4];
                boolean pativo   = (Boolean) pr[5];
                if (!first) out.print(",");
                first = false;
        %>
        '<%= pid %>': {
            titulo: '<%= ptitulo.replace("'", "\\'") %>',
            desconto: <%= pdesc %>,
            inicio: '<%= pinicio %>',
            fim: '<%= pfim %>',
            prods: [],
            ativo: <%= pativo %>
        }
        <%
            }
        %>
    };

    function selectPromo(id) {
        var p = promoData[id];
        if (!p) return;

        document.getElementById('hiddenId').value      = id;
        document.getElementById('hiddenAtivo').value   = p.ativo;
        document.getElementById('fieldTitulo').value   = p.titulo;
        document.getElementById('fieldDesconto').value = p.desconto;
        document.getElementById('fieldInicio').value   = p.inicio;
        document.getElementById('fieldFim').value      = p.fim;

        /* reset checkboxes */
        document.querySelectorAll('.prod-list input[type="checkbox"]').forEach(function(chk) {
            chk.checked = p.prods.indexOf(chk.value) !== -1;
        });

        /* toggle button */
        var btn = document.getElementById('btnToggle');
        if (p.ativo) {
            btn.textContent = 'Inativar promoção';
            btn.classList.remove('ativar');
            btn.onclick = function() { return confirm('Inativar ' + p.titulo + '?'); };
        } else {
            btn.textContent = 'Ativar promoção';
            btn.classList.add('ativar');
            btn.onclick = function() { return confirm('Ativar ' + p.titulo + '?'); };
        }

        /* highlight row */
        document.querySelectorAll('.promos-table tbody tr').forEach(function(row) {
            row.classList.remove('selected');
        });
        document.querySelectorAll('.promos-table tbody tr').forEach(function(row) {
            if (row.dataset.titulo === p.titulo.toLowerCase()) row.classList.add('selected');
        });
    }

    function filterTable() {
        var q      = document.getElementById('searchInput').value.toLowerCase();
        var estado = document.getElementById('filterEstado').value;
        document.querySelectorAll('#promosTable tbody tr').forEach(function(row) {
            var titulo = row.dataset.titulo || '';
            var ativo  = row.dataset.ativo  || '';
            var ok = titulo.includes(q) && (!estado || ativo === estado);
            row.style.display = ok ? '' : 'none';
        });
    }
</script>

</body>
</html>

