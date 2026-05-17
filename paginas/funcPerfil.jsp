<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*, java.sql.*, java.security.MessageDigest, java.nio.charset.StandardCharsets" %>
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
    if (!"funcionario".equals(sess.getAttribute("userRole"))) { response.sendRedirect("dashboard.jsp"); return; }

    String funcName = (String) sess.getAttribute("userName");
    if (funcName == null) funcName = "Funcionário";

    String successMsg = (String) sess.getAttribute("success");
    if (successMsg != null) sess.removeAttribute("success");
    String errorMsg = null;

    if ("POST".equalsIgnoreCase(request.getMethod())) {
        Integer userId = (Integer) sess.getAttribute("userId");
        String postAction = request.getParameter("action");
        if ("updateProfile".equals(postAction)) {
            String nome = request.getParameter("nome");
            String email = request.getParameter("email");
            String telefone = request.getParameter("telefone");
            if (nome == null || nome.isBlank() || email == null || email.isBlank()) {
                errorMsg = "Nome e email são obrigatórios.";
            } else {
                try {
                    Connection conn = getConnection();
                    PreparedStatement ps = conn.prepareStatement(
                        "UPDATE utilizadores SET nome=?, email=?, telefone=? WHERE id_utilizador=?");
                    ps.setString(1, nome.trim()); ps.setString(2, email.trim());
                    ps.setString(3, telefone != null ? telefone.trim() : null); ps.setInt(4, userId);
                    ps.executeUpdate(); closeAll(null, ps, conn);
                    sess.setAttribute("userName", nome.trim());
                    sess.setAttribute("userEmail", email.trim());
                    sess.setAttribute("success", "Perfil atualizado com sucesso.");
                    response.sendRedirect("funcPerfil.jsp"); return;
                } catch (Exception e) { errorMsg = "Erro ao guardar: " + e.getMessage(); }
            }
        } else if ("changePassword".equals(postAction)) {
            String pwAtual = request.getParameter("password");
            String pwNova  = request.getParameter("confirmPassword");
            if (pwAtual == null || pwAtual.isBlank() || pwNova == null || pwNova.isBlank()) {
                errorMsg = "Preencha todos os campos de password.";
            } else if (pwNova.length() < 6) {
                errorMsg = "A nova password deve ter mínimo 6 caracteres.";
            } else {
                try {
                    Connection conn = getConnection();
                    PreparedStatement ps = conn.prepareStatement(
                        "SELECT password_hash FROM utilizadores WHERE id_utilizador=?");
                    ps.setInt(1, userId); ResultSet rs = ps.executeQuery();
                    String storedHash = rs.next() ? rs.getString("password_hash") : "";
                    rs.close(); ps.close();
                    if (!hashPassword(pwAtual).equals(storedHash)) {
                        errorMsg = "Password atual incorreta.";
                        conn.close();
                    } else {
                        ps = conn.prepareStatement(
                            "UPDATE utilizadores SET password_hash=? WHERE id_utilizador=?");
                        ps.setString(1, hashPassword(pwNova)); ps.setInt(2, userId);
                        ps.executeUpdate(); closeAll(null, ps, conn);
                        sess.setAttribute("success", "Password alterada com sucesso.");
                        response.sendRedirect("funcPerfil.jsp"); return;
                    }
                } catch (Exception e) { errorMsg = "Erro ao alterar password: " + e.getMessage(); }
            }
        }
    }

    String perfilNome = funcName;
    String perfilEmail = "";
    String perfilTelefone = "";
    String estado = "Ativo";
    String encomendasValidadas = "0";
    String membroDesde = "";

    try {
        Connection conn = getConnection();

        PreparedStatement ps = conn.prepareStatement(
            "SELECT nome, email, telefone, data_registo, ativo FROM utilizadores WHERE id_utilizador = ?");
        ps.setInt(1, (Integer) sess.getAttribute("userId"));
        ResultSet rs = ps.executeQuery();
        if (rs.next()) {
            perfilNome      = rs.getString("nome");
            perfilEmail     = rs.getString("email");
            perfilTelefone  = rs.getString("telefone") != null ? rs.getString("telefone") : "";
            estado          = rs.getBoolean("ativo") ? "Ativo" : "Inativo";
            String dr       = rs.getString("data_registo");
            membroDesde     = (dr != null && dr.length() >= 10) ? dr.substring(0, 10) : (dr != null ? dr : "");
        }
        rs.close(); ps.close();

        PreparedStatement ps2 = conn.prepareStatement("SELECT COUNT(*) FROM encomenda");
        ResultSet rs2 = ps2.executeQuery();
        if (rs2.next()) encomendasValidadas = String.valueOf(rs2.getInt(1));
        rs2.close(); ps2.close();

        conn.close();
    } catch (Exception e) {
        // page renders with defaults on error
    }

    String activePage = "perfil";
%>
<!DOCTYPE html>
<html lang="pt">
<head>
    <meta charset="UTF-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <title>FelixUberShop – Perfil Funcionário</title>
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

        .page-title {
            font-size: 1.3rem;
            font-weight: 700;
            color: #fff;
            margin-bottom: 20px;
        }

        .alert {
            border-radius: 8px;
            padding: 11px 16px;
            font-size: .86rem;
            margin-bottom: 18px;
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

        .profile-row {
            display: grid;
            grid-template-columns: 1fr 265px;
            gap: 18px;
            margin-bottom: 18px;
            align-items: start;
        }

        .panel {
            background: #2b2b2b;
            border: 1px solid #333;
            border-radius: 10px;
            overflow: hidden;
        }

        .panel-header {
            padding: 13px 20px;
            border-bottom: 1px solid #333;
            display: flex;
            align-items: center;
            gap: 9px;
        }

        .panel-title {
            font-size: .9rem;
            font-weight: 700;
            color: #e8e8e8;
        }

        .panel-title-icon {
            fill: #00CE86;
            width: 16px;
            height: 16px;
        }

        .panel-body {
            padding: 20px;
        }

        .form-group {
            margin-bottom: 16px;
        }

        label {
            display: block;
            font-size: .79rem;
            color: #999;
            margin-bottom: 6px;
            letter-spacing: .3px;
        }

        label .req {
            color: #00CE86;
        }

        .input-wrap {
            position: relative;
        }

        .input-wrap .ico {
            position: absolute;
            left: 13px;
            top: 50%;
            transform: translateY(-50%);
            display: flex;
            color: #555;
        }

        .input-wrap .ico svg {
            width: 15px;
            height: 15px;
            fill: currentColor;
        }

        input[type="text"],
        input[type="email"],
        input[type="tel"],
        input[type="password"] {
            width: 100%;
            background: #1e1e1e;
            border: 1px solid #3a3a3a;
            border-radius: 7px;
            color: #e0e0e0;
            font-size: .9rem;
            padding: 10px 12px 10px 38px;
            outline: none;
            transition: border-color .2s, box-shadow .2s;
        }

        input::placeholder {
            color: #4a4a4a;
        }

        input:focus {
            border-color: #00CE86;
            box-shadow: 0 0 0 3px rgba(0, 206, 134, .12);
        }

        input.err {
            border-color: #c0392b;
        }

        .btn-save {
            background: #00CE86;
            color: #111;
            border: none;
            border-radius: 7px;
            padding: 11px 26px;
            font-size: .9rem;
            font-weight: 700;
            cursor: pointer;
            transition: background .2s, transform .1s;
        }

        .btn-save:hover {
            background: #00b876;
        }

        .btn-save:active {
            transform: scale(.98);
        }

        .btn-save-outline {
            background: none;
            border: 1px solid #00CE86;
            color: #00CE86;
            border-radius: 7px;
            padding: 10px 22px;
            font-size: .9rem;
            font-weight: 700;
            cursor: pointer;
            transition: background .2s;
        }

        .btn-save-outline:hover {
            background: rgba(0, 206, 134, .08);
        }

        .form-actions {
            display: flex;
            gap: 10px;
            margin-top: 4px;
        }

        .summary-list {
            list-style: none;
        }

        .summary-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 13px 20px;
            border-bottom: 1px solid #2e2e2e;
            font-size: .86rem;
        }

        .summary-item:last-child {
            border-bottom: none;
        }

        .summary-key {
            color: #777;
            display: flex;
            align-items: center;
            gap: 7px;
        }

        .summary-key svg {
            fill: #555;
            width: 14px;
            height: 14px;
        }

        .summary-val {
            font-weight: 600;
            color: #e0e0e0;
        }

        .badge-ativo {
            background: rgba(0, 206, 134, .12);
            color: #00CE86;
            border: 1px solid rgba(0, 206, 134, .3);
            border-radius: 20px;
            padding: 2px 10px;
            font-size: .73rem;
            font-weight: 700;
        }

        .summary-val-accent {
            font-weight: 700;
            color: #00CE86;
            font-size: 1rem;
        }

        .security-meta {
            display: flex;
            align-items: center;
            gap: 8px;
            font-size: .82rem;
            color: #666;
            margin-bottom: 20px;
        }

        .security-meta svg {
            fill: #555;
            width: 15px;
            height: 15px;
        }

        .security-meta strong {
            color: #aaa;
        }

        .row-2 {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 14px;
        }

        .hint {
            font-size: .74rem;
            color: #555;
            margin-top: 5px;
        }

        .pw-hint {
            font-size: .74rem;
            margin-top: 5px;
        }

        .toggle-pw {
            position: absolute;
            right: 11px;
            top: 50%;
            transform: translateY(-50%);
            background: none;
            border: none;
            cursor: pointer;
            color: #555;
            display: flex;
            padding: 0;
            transition: color .2s;
        }

        .toggle-pw:hover {
            color: #00CE86;
        }

        .toggle-pw svg {
            width: 15px;
            height: 15px;
            fill: currentColor;
        }

        @media (max-width: 820px) {
            .profile-row {
                grid-template-columns: 1fr;
            }

            .row-2 {
                grid-template-columns: 1fr;
            }
        }

        @media (max-width: 600px) {
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
        }
    </style>
</head>
<body>

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
        <a href="LogoutServlet" class="btn-sair">Sair</a>
    </div>
</nav>

<div class="app-shell">

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
            <li><a href="saldoClientes.jsp">
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
            <li><a href="funcPerfil.jsp" class="active">
                <svg viewBox="0 0 24 24">
                    <path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/>
                </svg>
                <span>Perfil</span></a></li>
        </ul>
    </aside>

    <main class="main-content">
        <h1 class="page-title">Perfil</h1>

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

        <div class="profile-row">

            <div class="panel">
                <div class="panel-header">
                    <svg class="panel-title-icon" viewBox="0 0 24 24">
                        <path d="M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25zM20.71 7.04a1 1 0 0 0 0-1.41l-2.34-2.34a1 1 0 0 0-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83z"/>
                    </svg>
                    <span class="panel-title">Editar dados pessoais</span>
                </div>
                <div class="panel-body">
                    <form action="funcPerfil.jsp" method="post" autocomplete="off">
                        <input type="hidden" name="action" value="updateProfile"/>

                        <div class="form-group">
                            <label for="nome">Nome completo <span class="req">*</span></label>
                            <div class="input-wrap">
                                <span class="ico"><svg viewBox="0 0 24 24"><path
                                        d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/></svg></span>
                                <input type="text" id="nome" name="nome"
                                       value="<%= perfilNome %>" required/>
                            </div>
                        </div>

                        <div class="form-group">
                            <label for="email">Email <span class="req">*</span></label>
                            <div class="input-wrap">
                                <span class="ico"><svg viewBox="0 0 24 24"><path
                                        d="M20 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 4-8 5-8-5V6l8 5 8-5v2z"/></svg></span>
                                <input type="email" id="email" name="email"
                                       value="<%= perfilEmail %>" required/>
                            </div>
                        </div>

                        <div class="form-group">
                            <label for="telefone">Telefone</label>
                            <div class="input-wrap">
                                <span class="ico"><svg viewBox="0 0 24 24"><path
                                        d="M6.62 10.79a15.05 15.05 0 0 0 6.59 6.59l2.2-2.2c.27-.27.67-.36 1.02-.24 1.12.37 2.33.57 3.57.57.55 0 1 .45 1 1V20c0 .55-.45 1-1 1C10.28 21 3 13.72 3 4.5c0-.55.45-1 1-1H7c.55 0 1 .45 1 1 0 1.25.2 2.45.57 3.57.11.35.03.74-.24 1.02l-2.2 2.2z"/></svg></span>
                                <input type="tel" id="telefone" name="telefone"
                                       value="<%= perfilTelefone %>"
                                       pattern="[0-9+\s\-]{7,15}"/>
                            </div>
                        </div>

                        <div class="form-actions">
                            <button type="submit" class="btn-save">Guardar</button>
                        </div>
                    </form>
                </div>
            </div>

            <div class="panel">
                <div class="panel-header">
                    <svg class="panel-title-icon" viewBox="0 0 24 24">
                        <path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/>
                    </svg>
                    <span class="panel-title">Resumo da conta</span>
                </div>

                <div style="padding:12px 20px 0; font-size:.78rem; color:#666; border-bottom:1px solid #2e2e2e; padding-bottom:12px;">
                        <span style="background:rgba(0,206,134,.08);border:1px solid rgba(0,206,134,.2);color:#00CE86;border-radius:20px;padding:3px 12px;font-size:.73rem;font-weight:700;">
                            Perfil Funcionário
                        </span>
                </div>

                <ul class="summary-list">
                    <li class="summary-item">
                            <span class="summary-key">
                                <svg viewBox="0 0 24 24"><path
                                        d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 14l-4-4 1.41-1.41L10 13.17l6.59-6.59L18 8l-8 8z"/></svg>
                                Estado
                            </span>
                        <span class="badge-ativo"><%= estado %></span>
                    </li>
                    <li class="summary-item">
                            <span class="summary-key">
                                <svg viewBox="0 0 24 24"><path
                                        d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z"/></svg>
                                Encomendas validadas
                            </span>
                        <span class="summary-val-accent"><%= encomendasValidadas %></span>
                    </li>
                    <li class="summary-item">
                            <span class="summary-key">
                                <svg viewBox="0 0 24 24"><path
                                        d="M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zM12 20c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8zm.5-13H11v6l5.25 3.15.75-1.23-4.5-2.67V7z"/></svg>
                                Membro desde
                            </span>
                        <span class="summary-val"><%= membroDesde %></span>
                    </li>
                </ul>
            </div>

        </div>

        <div class="panel">
            <div class="panel-header">
                <svg class="panel-title-icon" viewBox="0 0 24 24">
                    <path d="M18 8h-1V6A5 5 0 0 0 7 6v2H6a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V10a2 2 0 0 0-2-2zm-6 9a2 2 0 1 1 0-4 2 2 0 0 1 0 4zm3.1-9H8.9V6a3.1 3.1 0 0 1 6.2 0v2z"/>
                </svg>
                <span class="panel-title">Segurança</span>
            </div>
            <div class="panel-body">

                <div class="security-meta">
                    <svg viewBox="0 0 24 24">
                        <path d="M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zM12 20c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8zm.5-13H11v6l5.25 3.15.75-1.23-4.5-2.67V7z"/>
                    </svg>
                    Último login: <strong>—</strong>
                </div>

                <form action="funcPerfil.jsp" method="post" autocomplete="off"
                      onsubmit="return validatePw()">
                    <input type="hidden" name="action" value="changePassword"/>

                    <div class="row-2">

                        <div class="form-group">
                            <label for="password">Nova password <span class="req">*</span></label>
                            <p style="font-size:.74rem;color:#555;margin-bottom:8px;">Em branco para não alterar</p>
                            <div class="input-wrap">
                                <span class="ico"><svg viewBox="0 0 24 24"><path
                                        d="M18 8h-1V6A5 5 0 0 0 7 6v2H6a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V10a2 2 0 0 0-2-2zm-6 9a2 2 0 1 1 0-4 2 2 0 0 1 0 4zm3.1-9H8.9V6a3.1 3.1 0 0 1 6.2 0v2z"/></svg></span>
                                <input type="password" id="password" name="password"
                                       placeholder="••••••" minlength="6"/>
                                <button type="button" class="toggle-pw"
                                        onclick="togglePw('password','eye1')">
                                    <svg id="eye1" viewBox="0 0 24 24">
                                        <path d="M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5C21.27 7.61 17 4.5 12 4.5zm0 12.5a5 5 0 1 1 0-10 5 5 0 0 1 0 10zm0-8a3 3 0 1 0 0 6 3 3 0 0 0 0-6z"/>
                                    </svg>
                                </button>
                            </div>
                            <p class="hint">Mínimo 6 caracteres</p>
                        </div>

                        <div class="form-group">
                            <label for="confirmPassword">Confirmar password <span class="req">*</span></label>
                            <p style="font-size:.74rem;color:#555;margin-bottom:8px;">&nbsp;</p>
                            <div class="input-wrap">
                                <span class="ico"><svg viewBox="0 0 24 24"><path
                                        d="M18 8h-1V6A5 5 0 0 0 7 6v2H6a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V10a2 2 0 0 0-2-2zm-6 9a2 2 0 1 1 0-4 2 2 0 0 1 0 4zm3.1-9H8.9V6a3.1 3.1 0 0 1 6.2 0v2z"/></svg></span>
                                <input type="password" id="confirmPassword" name="confirmPassword"
                                       placeholder="••••••"/>
                                <button type="button" class="toggle-pw"
                                        onclick="togglePw('confirmPassword','eye2')">
                                    <svg id="eye2" viewBox="0 0 24 24">
                                        <path d="M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5C21.27 7.61 17 4.5 12 4.5zm0 12.5a5 5 0 1 1 0-10 5 5 0 0 1 0 10zm0-8a3 3 0 1 0 0 6 3 3 0 0 0 0-6z"/>
                                    </svg>
                                </button>
                            </div>
                            <p class="pw-hint" id="pwMatchHint">&nbsp;</p>
                        </div>

                    </div>

                    <div class="form-actions">
                        <button type="submit" class="btn-save-outline">Guardar alterações</button>
                    </div>
                </form>
            </div>
        </div>

    </main>
</div>

<script>
    const eyeOpen = '<path d="M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5C21.27 7.61 17 4.5 12 4.5zm0 12.5a5 5 0 1 1 0-10 5 5 0 0 1 0 10zm0-8a3 3 0 1 0 0 6 3 3 0 0 0 0-6z"/>';
    const eyeClosed = '<path d="M12 7c2.76 0 5 2.24 5 5 0 .65-.13 1.26-.36 1.83l2.92 2.92c1.51-1.26 2.7-2.89 3.43-4.75C21.27 7.61 17 4.5 12 4.5c-1.29 0-2.53.25-3.67.7l2.16 2.16C11 7.13 11.48 7 12 7zm-9.71-1.14L4.47 8.04C2.75 9.33 1.4 11.1.72 13.15 2.46 17.54 6.72 20.5 12 20.5c1.51 0 2.97-.3 4.29-.83l.42.42L19.73 23 21 21.73 3.27 4l-.98 1.86zM7 12c0-2.76 2.24-5 5-5 .77 0 1.5.18 2.14.49L12 9.63c-.2-.08-.59-.13-1-.13C9.34 9.5 8 10.84 8 12.5c0 .41.05.8.13 1.18L6.15 11.7C6.05 11.49 7 11.27 7 12z"/>';

    function togglePw(inputId, iconId) {
        const input = document.getElementById(inputId);
        const icon = document.getElementById(iconId);
        input.type = input.type === 'password' ? 'text' : 'password';
        icon.innerHTML = input.type === 'text' ? eyeClosed : eyeOpen;
    }

    const pwField = document.getElementById('password');
    const confirmField = document.getElementById('confirmPassword');
    const matchHint = document.getElementById('pwMatchHint');

    function checkMatch() {
        if (!confirmField.value) {
            matchHint.textContent = '\u00a0';
            matchHint.style.color = '';
            return;
        }
        const match = pwField.value === confirmField.value;
        matchHint.textContent = match ? '✓ Passwords coincidem' : '✗ Não coincidem';
        matchHint.style.color = match ? '#00CE86' : '#f08080';
    }

    pwField.addEventListener('input', checkMatch);
    confirmField.addEventListener('input', checkMatch);

    function validatePw() {
        const pw = pwField.value;
        if (!pw) return true;
        if (pw.length < 6) {
            pwField.focus();
            return false;
        }
        if (pw !== confirmField.value) {
            confirmField.focus();
            return false;
        }
        return true;
    }
</script>

</body>
</html>
