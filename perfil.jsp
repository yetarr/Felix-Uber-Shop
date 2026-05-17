<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*" %>
<%

    String clienteName = "cliente de teste";
    String perfilNome = "Cliente Teste";
    String perfilEmail = "cliente@felixubershop.pt";
    String perfilTelefone = "912 000 000";

    String estado = "Ativo";
    String saldo = "50,00 €";
    String totalEnc = "3";
    String membroDesde = "01/05/2026";
    String ultimoLogin = "04/05/2026 14:30";

    String successMsg = (String) request.getAttribute("success");
    String errorMsg = (String) request.getAttribute("error");

    if (request.getParameter("nome") != null) perfilNome = request.getParameter("nome");
    if (request.getParameter("email") != null) perfilEmail = request.getParameter("email");
    if (request.getParameter("telefone") != null) perfilTelefone = request.getParameter("telefone");

    String activePage = "perfil";
%>
<!DOCTYPE html>
<html lang="pt">
<head>
    <meta charset="UTF-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <title>FelixUberShop – Perfil</title>
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
            background-color: #2a2a2a;
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
            font-size: 0.87rem;
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
            font-size: 0.8rem;
            padding: 5px 14px;
            border-radius: 6px;
            cursor: pointer;
            text-decoration: none;
            transition: border-color 0.2s, color 0.2s;
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
            width: 210px;
            flex-shrink: 0;
            background-color: #111;
            border-right: 1px solid #222;
            display: flex;
            flex-direction: column;
            padding: 24px 0 16px;
        }

        .sidebar-label {
            font-size: 0.68rem;
            font-weight: 700;
            letter-spacing: 1.2px;
            color: #444;
            text-transform: uppercase;
            padding: 0 20px 14px;
        }

        .sidebar-nav {
            list-style: none;
        }

        .sidebar-nav li a {
            display: flex;
            align-items: center;
            gap: 11px;
            padding: 11px 20px;
            text-decoration: none;
            font-size: 0.88rem;
            color: #888;
            border-left: 3px solid transparent;
            transition: background 0.15s, color 0.15s, border-color 0.15s;
        }

        .sidebar-nav li a:hover {
            background: rgba(255, 255, 255, 0.04);
            color: #ddd;
        }

        .sidebar-nav li a.active {
            border-left-color: #00CE86;
            background: rgba(0, 206, 134, 0.07);
            color: #00CE86;
            font-weight: 600;
        }

        .sidebar-nav li a svg {
            width: 17px;
            height: 17px;
            fill: currentColor;
            flex-shrink: 0;
        }

        .main-content {
            flex: 1;
            padding: 28px 28px 48px;
            overflow-y: auto;
            min-width: 0;
        }

        .page-title {
            font-size: 1.35rem;
            font-weight: 700;
            color: #fff;
            margin-bottom: 20px;
        }

        .alert {
            border-radius: 8px;
            padding: 11px 16px;
            font-size: 0.86rem;
            margin-bottom: 20px;
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .alert svg {
            width: 17px;
            height: 17px;
            flex-shrink: 0;
        }

        .alert-success {
            background: rgba(0, 206, 134, 0.1);
            border: 1px solid rgba(0, 206, 134, 0.3);
            color: #00CE86;
        }

        .alert-error {
            background: rgba(220, 60, 60, 0.1);
            border: 1px solid rgba(220, 60, 60, 0.3);
            color: #f08080;
        }

        .profile-row {
            display: grid;
            grid-template-columns: 1fr 260px;
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
            padding: 14px 20px;
            border-bottom: 1px solid #333;
            display: flex;
            align-items: center;
            gap: 9px;
        }

        .panel-title {
            font-size: 0.9rem;
            font-weight: 700;
            color: #e8e8e8;
        }

        .panel-title-icon {
            fill: #00CE86;
            width: 17px;
            height: 17px;
        }

        .panel-body {
            padding: 20px;
        }

        .form-group {
            margin-bottom: 16px;
        }

        label {
            display: block;
            font-size: 0.79rem;
            color: #999;
            margin-bottom: 6px;
            letter-spacing: 0.3px;
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
            background-color: #1e1e1e;
            border: 1px solid #3a3a3a;
            border-radius: 7px;
            color: #e0e0e0;
            font-size: 0.9rem;
            padding: 10px 12px 10px 38px;
            outline: none;
            transition: border-color 0.2s, box-shadow 0.2s;
        }

        input::placeholder {
            color: #4a4a4a;
        }

        input:focus {
            border-color: #00CE86;
            box-shadow: 0 0 0 3px rgba(0, 206, 134, 0.12);
        }

        .row-2 {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 14px;
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
            transition: color 0.2s;
        }

        .toggle-pw:hover {
            color: #00CE86;
        }

        .toggle-pw svg {
            width: 15px;
            height: 15px;
            fill: currentColor;
        }

        .btn-save {
            background-color: #00CE86;
            color: #111;
            border: none;
            border-radius: 7px;
            padding: 11px 26px;
            font-size: 0.9rem;
            font-weight: 700;
            cursor: pointer;
            transition: background 0.2s, transform 0.1s;
        }

        .btn-save:hover {
            background: #00b876;
        }

        .btn-save:active {
            transform: scale(0.98);
        }

        .btn-save-outline {
            background: none;
            border: 1px solid #00CE86;
            color: #00CE86;
            border-radius: 7px;
            padding: 10px 24px;
            font-size: 0.9rem;
            font-weight: 700;
            cursor: pointer;
            transition: background 0.2s;
        }

        .btn-save-outline:hover {
            background: rgba(0, 206, 134, 0.08);
        }

        .form-actions {
            display: flex;
            gap: 10px;
            margin-top: 4px;
        }

        .summary-list {
            list-style: none;
            display: flex;
            flex-direction: column;
        }

        .summary-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 13px 20px;
            border-bottom: 1px solid #2e2e2e;
            font-size: 0.86rem;
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
            background: rgba(0, 206, 134, 0.12);
            color: #00CE86;
            border: 1px solid rgba(0, 206, 134, 0.3);
            border-radius: 20px;
            padding: 2px 10px;
            font-size: 0.74rem;
            font-weight: 700;
        }

        .security-meta {
            display: flex;
            align-items: center;
            gap: 8px;
            font-size: 0.82rem;
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

        .hint {
            font-size: 0.74rem;
            color: #555;
            margin-top: 5px;
        }

        .pw-match-hint {
            font-size: 0.74rem;
            margin-top: 5px;
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
                padding: 16px;
            }
        }
    </style>
</head>
<body>

<!-- TOP NAV -->
<nav class="topnav">
    <a href="index.jsp" class="nav-brand">FelixUberShop</a>
    <div class="nav-right">
        <div class="nav-user">
            <svg viewBox="0 0 24 24">
                <path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/>
            </svg>
            Olá, <strong style="color:#e0e0e0;margin-left:4px;"><%= clienteName %>
        </strong>
        </div>
        <a href="LogoutServlet" class="btn-sair">Sair</a>
    </div>
</nav>

<div class="app-shell">

    <!-- SIDEBAR -->
    <aside class="sidebar">
        <div class="sidebar-label">Área Cliente</div>
        <ul class="sidebar-nav">
            <li>
                <a href="dashboard.jsp" class="<%= "dashboard".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24">
                        <path d="M3 13h8V3H3v10zm0 8h8v-6H3v6zm10 0h8V11h-8v10zm0-18v6h8V3h-8z"/>
                    </svg>
                    <span>Dashboard</span>
                </a>
            </li>
            <li>
                <a href="perfil.jsp" class="<%= "perfil".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24">
                        <path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/>
                    </svg>
                    <span>Perfil</span>
                </a>
            </li>
            <li>
                <a href="carteira.jsp" class="<%= "carteira".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24">
                        <path d="M21 7H3c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V9c0-1.1-.9-2-2-2zm-1 12H4V9h16v10zm-5-5a2 2 0 1 1 4 0 2 2 0 0 1-4 0zM3 5h16V3H3z"/>
                    </svg>
                    <span>Carteira</span>
                </a>
            </li>
            <li>
                <a href="encomendas.jsp" class="<%= "encomendas".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24">
                        <path d="M20 6h-2.18A3 3 0 0 0 15 4H9a3 3 0 0 0-2.82 2H4c-1.1 0-2 .9-2 2v11c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-11 0h6c.55 0 1 .45 1 1s-.45 1-1 1H9c-.55 0-1-.45-1-1s.45-1 1-1zM8 13h8v1.5H8V13zm0 3h5v1.5H8V16z"/>
                    </svg>
                    <span>Encomendas</span>
                </a>
            </li>
        </ul>
    </aside>

    <!-- MAIN -->
    <main class="main-content">
        <h1 class="page-title">Perfil</h1>

        <!-- Flash messages -->
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

        <!-- TOP ROW: Edit form + Account summary -->
        <div class="profile-row">

            <!-- ── DADOS PESSOAIS FORM ───────────────────── -->
            <div class="panel">
                <div class="panel-header">
                    <svg class="panel-title-icon" viewBox="0 0 24 24">
                        <path d="M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25zM20.71 7.04a1 1 0 0 0 0-1.41l-2.34-2.34a1 1 0 0 0-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83z"/>
                    </svg>
                    <span class="panel-title">Editar dados pessoais</span>
                </div>
                <div class="panel-body">
                    <form action="ProfileServlet" method="post" autocomplete="off">
                        <input type="hidden" name="action" value="updateProfile"/>

                        <!-- Nome -->
                        <div class="form-group">
                            <label for="nome">Nome completo <span class="req">*</span></label>
                            <div class="input-wrap">
                                    <span class="ico">
                                        <svg viewBox="0 0 24 24"><path
                                                d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/></svg>
                                    </span>
                                <input type="text" id="nome" name="nome"
                                       value="<%= perfilNome %>" required/>
                            </div>
                        </div>

                        <!-- Email -->
                        <div class="form-group">
                            <label for="email">Email <span class="req">*</span></label>
                            <div class="input-wrap">
                                    <span class="ico">
                                        <svg viewBox="0 0 24 24"><path
                                                d="M20 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 4-8 5-8-5V6l8 5 8-5v2z"/></svg>
                                    </span>
                                <input type="email" id="email" name="email"
                                       value="<%= perfilEmail %>" required/>
                            </div>
                        </div>

                        <!-- Telefone -->
                        <div class="form-group">
                            <label for="telefone">Telefone</label>
                            <div class="input-wrap">
                                    <span class="ico">
                                        <svg viewBox="0 0 24 24"><path
                                                d="M6.62 10.79a15.05 15.05 0 0 0 6.59 6.59l2.2-2.2c.27-.27.67-.36 1.02-.24 1.12.37 2.33.57 3.57.57.55 0 1 .45 1 1V20c0 .55-.45 1-1 1C10.28 21 3 13.72 3 4.5c0-.55.45-1 1-1H7c.55 0 1 .45 1 1 0 1.25.2 2.45.57 3.57.11.35.03.74-.24 1.02l-2.2 2.2z"/></svg>
                                    </span>
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

            <!-- ── ACCOUNT SUMMARY ───────────────────────── -->
            <div class="panel">
                <div class="panel-header">
                    <svg class="panel-title-icon" viewBox="0 0 24 24">
                        <path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/>
                    </svg>
                    <span class="panel-title">Resumo da conta</span>
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
                                        d="M11.8 10.9c-2.27-.59-3-1.2-3-2.15 0-1.09 1.01-1.85 2.7-1.85 1.78 0 2.44.85 2.5 2.1h2.21c-.07-1.72-1.12-3.3-3.21-3.81V3h-3v2.16C9.56 5.67 8 6.84 8 8.75c0 2.31 1.91 3.46 4.7 4.13 2.5.6 3 1.48 3 2.41 0 .69-.49 1.79-2.7 1.79-2.06 0-2.87-.92-2.98-2.1H7.82c.12 2.19 1.76 3.42 3.68 3.83V21h3v-2.15c1.95-.37 3.5-1.5 3.5-3.55 0-2.84-2.43-3.81-4.7-4.4z"/></svg>
                                Saldo
                            </span>
                        <span class="summary-val" style="color:#00CE86;"><%= saldo %></span>
                    </li>
                    <li class="summary-item">
                            <span class="summary-key">
                                <svg viewBox="0 0 24 24"><path
                                        d="M20 6h-2.18A3 3 0 0 0 15 4H9a3 3 0 0 0-2.82 2H4c-1.1 0-2 .9-2 2v11c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-11 0h6c.55 0 1 .45 1 1s-.45 1-1 1H9c-.55 0-1-.45-1-1s.45-1 1-1z"/></svg>
                                Encomendas
                            </span>
                        <span class="summary-val"><%= totalEnc %></span>
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

        </div><!-- end profile-row -->

        <!-- ── SECURITY SECTION ──────────────────────────── -->
        <div class="panel">
            <div class="panel-header">
                <svg class="panel-title-icon" viewBox="0 0 24 24">
                    <path d="M18 8h-1V6A5 5 0 0 0 7 6v2H6a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V10a2 2 0 0 0-2-2zm-6 9a2 2 0 1 1 0-4 2 2 0 0 1 0 4zm3.1-9H8.9V6a3.1 3.1 0 0 1 6.2 0v2z"/>
                </svg>
                <span class="panel-title">Segurança</span>
            </div>
            <div class="panel-body">

                <!-- Last login info -->
                <div class="security-meta">
                    <svg viewBox="0 0 24 24">
                        <path d="M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zM12 20c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8zm.5-13H11v6l5.25 3.15.75-1.23-4.5-2.67V7z"/>
                    </svg>
                    Último login: <strong><%= ultimoLogin %>
                </strong>
                </div>

                <!-- Change password form -->
                <form action="ProfileServlet" method="post" autocomplete="off"
                      onsubmit="return validatePw()">
                    <input type="hidden" name="action" value="changePassword"/>

                    <div class="row-2">
                        <!-- New password -->
                        <div class="form-group">
                            <label for="password">Nova password <span class="req">*</span></label>
                            <div class="input-wrap">
                                    <span class="ico">
                                        <svg viewBox="0 0 24 24"><path
                                                d="M18 8h-1V6A5 5 0 0 0 7 6v2H6a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V10a2 2 0 0 0-2-2zm-6 9a2 2 0 1 1 0-4 2 2 0 0 1 0 4zm3.1-9H8.9V6a3.1 3.1 0 0 1 6.2 0v2z"/></svg>
                                    </span>
                                <input type="password" id="password" name="password"
                                       placeholder="••••••" minlength="6"/>
                                <button type="button" class="toggle-pw"
                                        onclick="togglePw('password','eye1')" title="Mostrar">
                                    <svg id="eye1" viewBox="0 0 24 24">
                                        <path d="M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5C21.27 7.61 17 4.5 12 4.5zm0 12.5a5 5 0 1 1 0-10 5 5 0 0 1 0 10zm0-8a3 3 0 1 0 0 6 3 3 0 0 0 0-6z"/>
                                    </svg>
                                </button>
                            </div>
                            <p class="hint">Mínimo 6 caracteres</p>
                        </div>

                        <!-- Confirm password -->
                        <div class="form-group">
                            <label for="confirmPassword">Confirmar password <span class="req">*</span></label>
                            <div class="input-wrap">
                                    <span class="ico">
                                        <svg viewBox="0 0 24 24"><path
                                                d="M18 8h-1V6A5 5 0 0 0 7 6v2H6a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V10a2 2 0 0 0-2-2zm-6 9a2 2 0 1 1 0-4 2 2 0 0 1 0 4zm3.1-9H8.9V6a3.1 3.1 0 0 1 6.2 0v2z"/></svg>
                                    </span>
                                <input type="password" id="confirmPassword" name="confirmPassword"
                                       placeholder="••••••"/>
                                <button type="button" class="toggle-pw"
                                        onclick="togglePw('confirmPassword','eye2')" title="Mostrar">
                                    <svg id="eye2" viewBox="0 0 24 24">
                                        <path d="M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5C21.27 7.61 17 4.5 12 4.5zm0 12.5a5 5 0 1 1 0-10 5 5 0 0 1 0 10zm0-8a3 3 0 1 0 0 6 3 3 0 0 0 0-6z"/>
                                    </svg>
                                </button>
                            </div>
                            <p class="pw-match-hint" id="pwMatchHint">&nbsp;</p>
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
