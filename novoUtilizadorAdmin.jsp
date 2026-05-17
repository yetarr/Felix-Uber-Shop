<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%
    String adminName = "Administrador";
    String activePage = "utilizadores";

    String successMsg = (String) request.getAttribute("success");
    String errorMsg   = (String) request.getAttribute("error");
%>
<!DOCTYPE html>
<html lang="pt">
<head>
    <meta charset="UTF-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <title>novoUtilizadorAdmin</title>
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
            grid-template-columns: 1fr 220px;
            gap: 20px;
            align-items: start;
        }

        /* ── LEFT: FORM PANEL ────────────────────────────── */
        .form-panel {
            background: #2b2b2b;
            border: 1px solid #333;
            border-radius: 10px;
            padding: 22px 22px 18px;
            display: flex;
            flex-direction: column;
            gap: 18px;
        }

        .form-panel-title {
            font-size: 1rem;
            font-weight: 700;
            color: #e8e8e8;
        }

        /* Alert */
        .alert {
            border-radius: 7px;
            padding: 10px 14px;
            font-size: .84rem;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .alert svg {
            width: 15px;
            height: 15px;
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

        /* Perfil toggle */
        .perfil-group {
            display: flex;
            flex-direction: column;
            gap: 7px;
        }

        .field-label {
            font-size: .78rem;
            color: #888;
        }

        .perfil-toggle {
            display: grid;
            grid-template-columns: 1fr 1fr 1fr;
            gap: 8px;
        }

        .perfil-btn {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 7px;
            padding: 10px 8px;
            border-radius: 8px;
            border: 1px solid #3a3a3a;
            background: #1e1e1e;
            color: #888;
            font-size: .85rem;
            font-weight: 600;
            cursor: pointer;
            transition: border-color .2s, background .2s, color .2s;
        }

        .perfil-btn svg {
            width: 15px;
            height: 15px;
            fill: currentColor;
            flex-shrink: 0;
        }

        .perfil-btn:hover:not(.active) {
            border-color: #555;
            color: #bbb;
        }

        .perfil-btn.active {
            background: #00CE86;
            border-color: #00CE86;
            color: #111;
        }

        /* Form fields */
        .field-group {
            display: flex;
            flex-direction: column;
            gap: 6px;
        }

        .field-input {
            width: 100%;
            background: #1a1a1a;
            border: 1px solid #3a3a3a;
            border-radius: 7px;
            color: #fff;
            font-size: .88rem;
            padding: 9px 12px;
            outline: none;
            transition: border-color .2s, box-shadow .2s;
            font-family: inherit;
        }

        .field-input:focus {
            border-color: #00CE86;
            box-shadow: 0 0 0 3px rgba(0, 206, 134, .1);
        }

        .field-input::placeholder {
            color: #444;
        }

        .fields-row {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 12px;
        }

        /* Buttons */
        .btn-criar {
            width: 100%;
            padding: 12px;
            background: #00CE86;
            color: #111;
            border: none;
            border-radius: 8px;
            font-size: .95rem;
            font-weight: 700;
            cursor: pointer;
            transition: background .2s;
        }

        .btn-criar:hover {
            background: #00b876;
        }

        .link-voltar {
            display: block;
            text-align: center;
            color: #666;
            font-size: .84rem;
            text-decoration: none;
            padding: 10px;
            border: 1px solid #333;
            border-radius: 8px;
            transition: color .2s, border-color .2s;
        }

        .link-voltar:hover {
            color: #aaa;
            border-color: #555;
        }

        /* ── RIGHT: NOTES PANEL ──────────────────────────── */
        .notes-panel {
            background: #262626;
            border: 1px solid #333;
            border-radius: 10px;
            overflow: hidden;
        }

        .notes-header {
            padding: 13px 16px;
            border-bottom: 1px solid #333;
            font-size: .72rem;
            font-weight: 700;
            letter-spacing: 1.2px;
            color: #555;
            text-transform: uppercase;
        }

        .notes-body {
            padding: 4px 0 8px;
        }

        .notes-row {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 9px 16px;
            border-bottom: 1px solid #222;
            font-size: .83rem;
        }

        .notes-row:last-child {
            border-bottom: none;
        }

        .notes-label {
            color: #666;
        }

        .notes-value {
            color: #bbb;
            font-weight: 600;
            text-align: right;
        }

        .notes-value.green {
            color: #00CE86;
        }

        /* ── RESPONSIVE ──────────────────────────────────── */
        @media (max-width: 800px) {
            .page-grid {
                grid-template-columns: 1fr;
            }

            .notes-panel {
                display: none;
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

            .fields-row {
                grid-template-columns: 1fr;
            }

            .perfil-toggle {
                grid-template-columns: 1fr;
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

            <!-- LEFT: FORM -->
            <div class="form-panel">

                <div class="form-panel-title">Novo utilizador</div>

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

                <%-- TODO: ligar ao AdminUtilizadoresServlet com action=criar --%>
                <form action="AdminUtilizadoresServlet" method="post"
                      onsubmit="return validarForm()">
                    <input type="hidden" name="action" value="criar"/>
                    <input type="hidden" id="hiddenPerfil" name="perfil" value="Cliente"/>

                    <!-- Perfil toggle -->
                    <div class="perfil-group">
                        <span class="field-label">Perfil</span>
                        <div class="perfil-toggle">
                            <button type="button" class="perfil-btn active" id="btnCliente"
                                    onclick="selecionarPerfil('Cliente')">
                                <svg viewBox="0 0 24 24"><path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/></svg>
                                Cliente
                            </button>
                            <button type="button" class="perfil-btn" id="btnFuncionario"
                                    onclick="selecionarPerfil('Funcionário')">
                                <svg viewBox="0 0 24 24"><path d="M22.7 19l-9.1-9.1c.9-2.3.4-5-1.5-6.9-2-2-5-2.4-7.4-1.3L9 6 6 9 1.6 4.7C.4 7.1.9 10.1 2.9 12.1c1.9 1.9 4.6 2.4 6.9 1.5l9.1 9.1c.4.4 1 .4 1.4 0l2.3-2.3c.5-.4.5-1.1.1-1.4z"/></svg>
                                Funcionário
                            </button>
                            <button type="button" class="perfil-btn" id="btnAdmin"
                                    onclick="selecionarPerfil('Admin')">
                                <svg viewBox="0 0 24 24"><path d="M19.14 12.94c.04-.3.06-.61.06-.94 0-.32-.02-.64-.07-.94l2.03-1.58a.49.49 0 0 0 .12-.61l-1.92-3.32a.49.49 0 0 0-.59-.22l-2.39.96a7.01 7.01 0 0 0-1.62-.94l-.36-2.54a.484.484 0 0 0-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96a.47.47 0 0 0-.59.22L2.74 8.87a.47.47 0 0 0 .12.61l2.03 1.58c-.05.3-.09.63-.09.94s.02.64.07.94l-2.03 1.58a.49.49 0 0 0-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32a.47.47 0 0 0-.12-.61l-2.01-1.58zM12 15.6c-1.98 0-3.6-1.62-3.6-3.6s1.62-3.6 3.6-3.6 3.6 1.62 3.6 3.6-1.62 3.6-3.6 3.6z"/></svg>
                                Admin
                            </button>
                        </div>
                    </div>

                    <!-- Fields -->
                    <div class="field-group" style="margin-top:4px;">
                        <label class="field-label" for="fieldNome">Nome completo</label>
                        <input type="text" id="fieldNome" name="nome"
                               class="field-input"
                               placeholder="Nome do utilizador"
                               required/>
                    </div>

                    <div class="field-group">
                        <label class="field-label" for="fieldEmail">Email</label>
                        <input type="email" id="fieldEmail" name="email"
                               class="field-input"
                               placeholder="email@exemplo.com"
                               required/>
                    </div>

                    <div class="field-group">
                        <label class="field-label" for="fieldTel">Telefone</label>
                        <input type="text" id="fieldTel" name="telefone"
                               class="field-input"
                               placeholder="9XX XXX XXX"/>
                    </div>

                    <div class="fields-row">
                        <div class="field-group">
                            <label class="field-label" for="fieldPass">Password</label>
                            <input type="password" id="fieldPass" name="password"
                                   class="field-input"
                                   placeholder="••••••"
                                   required/>
                        </div>
                        <div class="field-group">
                            <label class="field-label" for="fieldPassConf">Confirmar password</label>
                            <input type="password" id="fieldPassConf" name="passwordConfirm"
                                   class="field-input"
                                   placeholder="••••••"
                                   required/>
                        </div>
                    </div>

                    <button type="submit" class="btn-criar">Criar utilizador</button>
                </form>

                <a href="utilizadoresAdmin.jsp" class="link-voltar">&larr; Voltar à lista</a>

            </div>

            <!-- RIGHT: NOTES -->
            <div class="notes-panel">
                <div class="notes-header">Notas</div>
                <div class="notes-body">
                    <div class="notes-row">
                        <span class="notes-label">Carteira</span>
                        <span class="notes-value">Criada automaticamente</span>
                    </div>
                    <div class="notes-row">
                        <span class="notes-label">Saldo inicial</span>
                        <span class="notes-value">0,00 &euro;</span>
                    </div>
                    <div class="notes-row">
                        <span class="notes-label">Estado</span>
                        <span class="notes-value green">Ativo</span>
                    </div>
                    <div class="notes-row">
                        <span class="notes-label">Password</span>
                        <span class="notes-value">Guardada com hash</span>
                    </div>
                </div>
            </div>

        </div><!-- end page-grid -->
    </main>
</div>

<script>
    function selecionarPerfil(perfil) {
        document.getElementById('hiddenPerfil').value = perfil;

        document.getElementById('btnCliente').classList.remove('active');
        document.getElementById('btnFuncionario').classList.remove('active');
        document.getElementById('btnAdmin').classList.remove('active');

        const map = { 'Cliente': 'btnCliente', 'Funcionário': 'btnFuncionario', 'Admin': 'btnAdmin' };
        document.getElementById(map[perfil]).classList.add('active');
    }

    function validarForm() {
        const pass  = document.getElementById('fieldPass').value;
        const conf  = document.getElementById('fieldPassConf').value;
        if (pass !== conf) {
            alert('As passwords não coincidem.');
            return false;
        }
        if (pass.length < 4) {
            alert('A password deve ter pelo menos 4 caracteres.');
            return false;
        }
        return true;
    }
</script>

</body>
</html>

