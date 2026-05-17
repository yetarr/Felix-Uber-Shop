<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*" %>
<%@ page import="java.sql.*" %>
<%@ include file="../basedados/basedados.h" %>
<%
    HttpSession sess = request.getSession(false);
    if (sess == null || sess.getAttribute("userId") == null) { response.sendRedirect("login.jsp"); return; }
    if (!"administrador".equals(sess.getAttribute("userRole"))) { response.sendRedirect("dashboard.jsp"); return; }

    String adminName = (String) sess.getAttribute("userName");
    if (adminName == null) adminName = "Administrador";
    String activePage = "produtos";

    String successMsg = (String) sess.getAttribute("success");
    if (successMsg != null) sess.removeAttribute("success");
    String errorMsg = null;

    if ("POST".equalsIgnoreCase(request.getMethod())) {
        String nome = request.getParameter("nome");
        String descricao = request.getParameter("descricao");
        String precoStr = request.getParameter("preco");
        String stockStr = request.getParameter("stock");
        String categoria = request.getParameter("categoria");
        if (nome == null || nome.isBlank() || precoStr == null || precoStr.isBlank()) {
            errorMsg = "Nome e preço são obrigatórios.";
        } else {
            try {
                double preco = Double.parseDouble(precoStr.replace(",", "."));
                int stock = stockStr != null && !stockStr.isBlank() ? Integer.parseInt(stockStr) : 0;
                Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(
                    "INSERT INTO produtos (nome, descricao, preco, stock, categoria) VALUES (?,?,?,?,?)");
                ps.setString(1, nome.trim());
                ps.setString(2, descricao != null ? descricao.trim() : null);
                ps.setDouble(3, preco);
                ps.setInt(4, stock);
                ps.setString(5, categoria != null ? categoria.trim() : null);
                ps.executeUpdate(); closeAll(null, ps, conn);
                logAuditoria("Produto", "criado", "Produto criado: " + nome.trim(), null, (Integer) sess.getAttribute("userId"));
                sess.setAttribute("success", "Produto criado com sucesso.");
                response.sendRedirect("produtosAdmin.jsp"); return;
            } catch (NumberFormatException e) { errorMsg = "Preço ou stock inválido."; }
            catch (Exception e) { errorMsg = "Erro ao criar produto: " + e.getMessage(); }
        }
    }
%>
<!DOCTYPE html>
<html lang="pt">
<head>
    <meta charset="UTF-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <title>NovoProdutoAdmin</title>
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

        .page-title {
            font-size: 1.3rem;
            font-weight: 700;
            color: #e8e8e8;
            margin-bottom: 22px;
        }

        /* ── TWO-COL LAYOUT ──────────────────────────────── */
        .page-grid {
            display: grid;
            grid-template-columns: 1fr 300px;
            gap: 20px;
            align-items: start;
        }

        /* ── LEFT: FORM PANEL ────────────────────────────── */
        .form-panel {
            background: #2b2b2b;
            border: 1px solid #333;
            border-radius: 10px;
            overflow: hidden;
        }

        .form-body {
            padding: 20px;
            display: flex;
            flex-direction: column;
            gap: 16px;
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

        /* Photo upload area */
        .photo-upload {
            height: 130px;
            background: #1e1e1e;
            border: 2px dashed #3a3a3a;
            border-radius: 10px;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            gap: 8px;
            cursor: pointer;
            transition: border-color .2s, background .2s;
            position: relative;
            overflow: hidden;
        }

        .photo-upload:hover {
            border-color: #555;
            background: #222;
        }

        .photo-upload svg {
            fill: #444;
            width: 32px;
            height: 32px;
        }

        .photo-upload span {
            font-size: .78rem;
            color: #555;
        }

        .photo-upload input[type="file"] {
            position: absolute;
            inset: 0;
            opacity: 0;
            cursor: pointer;
        }

        #photoPreviewImg {
            width: 100%;
            height: 100%;
            object-fit: cover;
            display: none;
            position: absolute;
            inset: 0;
        }

        /* Form fields */
        .field-group {
            display: flex;
            flex-direction: column;
            gap: 5px;
        }

        .field-label {
            font-size: .78rem;
            color: #888;
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

        textarea.field-input {
            resize: vertical;
            min-height: 72px;
        }

        .fields-row {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 12px;
        }

        /* Buttons */
        .btn-criar {
            width: 100%;
            padding: 11px;
            background: #00CE86;
            color: #111;
            border: none;
            border-radius: 7px;
            font-size: .95rem;
            font-weight: 700;
            cursor: pointer;
            transition: background .2s;
            margin-top: 4px;
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
            margin-top: 2px;
            transition: color .2s;
        }

        .link-voltar:hover {
            color: #aaa;
        }

        /* ── RIGHT: PREVIEW PANEL ────────────────────────── */
        .preview-panel {
            background: #262626;
            border: 1px solid #333;
            border-radius: 10px;
            overflow: hidden;
        }

        .preview-header {
            padding: 13px 16px;
            border-bottom: 1px solid #333;
            font-size: .75rem;
            font-weight: 700;
            letter-spacing: 1px;
            color: #555;
            text-transform: uppercase;
        }

        .preview-body {
            padding: 20px 16px;
        }

        .preview-card {
            background: #2b2b2b;
            border: 1px solid #333;
            border-radius: 10px;
            overflow: hidden;
        }

        .preview-card-img {
            width: 100%;
            height: 130px;
            background: #1e1e1e;
            display: flex;
            align-items: center;
            justify-content: center;
            overflow: hidden;
        }

        .preview-card-img svg {
            fill: #2e2e2e;
            width: 40px;
            height: 40px;
        }

        .preview-card-img img {
            width: 100%;
            height: 100%;
            object-fit: cover;
            display: none;
        }

        .preview-card-body {
            padding: 12px 14px;
            display: flex;
            flex-direction: column;
            gap: 5px;
        }

        .preview-card-nome {
            font-size: .95rem;
            font-weight: 700;
            color: #e0e0e0;
        }

        .preview-card-desc {
            font-size: .8rem;
            color: #888;
        }

        .preview-card-preco {
            font-size: 1.05rem;
            font-weight: 700;
            color: #00CE86;
            margin-top: 4px;
        }

        .preview-card-stock {
            font-size: .76rem;
            color: #666;
        }

        /* ── RESPONSIVE ──────────────────────────────────── */
        @media (max-width: 800px) {
            .page-grid {
                grid-template-columns: 1fr;
            }

            .preview-panel {
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

        <div class="page-title">Novo produto</div>

        <div class="page-grid">

            <!-- LEFT: FORM -->
            <div class="form-panel">
                <div class="form-body">

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

                    <%-- TODO: implementar upload de imagem (guardar em disco ou BD) --%>
                    <div class="photo-upload" id="photoUpload">
                        <img id="photoPreviewImg" src="" alt="preview"/>
                        <svg viewBox="0 0 24 24" id="photoIcon"><path d="M12 15.2A3.2 3.2 0 1 1 12 8.8a3.2 3.2 0 0 1 0 6.4zm0-8.2a5 5 0 1 0 0 10A5 5 0 0 0 12 7zM4 5h2.17L7.4 3.6A1 1 0 0 1 8.26 3h7.48a1 1 0 0 1 .86.6L17.83 5H20a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2z"/></svg>
                        <span id="photoLabel">Clica para adicionar foto</span>
                        <input type="file" id="fotoFile" accept="image/*" onchange="previewPhoto(this)"/>
                    </div>

                    <form action="novoProdutoAdmin.jsp" method="post"
                          onsubmit="return validarForm()">
                        <input type="hidden" name="action" value="criar"/>

                        <div class="field-group">
                            <label class="field-label" for="fieldNome">Nome</label>
                            <input type="text" id="fieldNome" name="nome"
                                   class="field-input"
                                   placeholder="ex: Arroz 1kg"
                                   oninput="atualizarPreview()"
                                   required/>
                        </div>

                        <div class="field-group">
                            <label class="field-label" for="fieldDesc">Descrição</label>
                            <textarea id="fieldDesc" name="descricao"
                                      class="field-input"
                                      placeholder="Breve descrição do produto..."
                                      rows="3"
                                      oninput="atualizarPreview()"></textarea>
                        </div>

                        <div class="fields-row">
                            <div class="field-group">
                                <label class="field-label" for="fieldPreco">Preço (&euro;)</label>
                                <input type="number" id="fieldPreco" name="preco"
                                       class="field-input"
                                       placeholder="0,00"
                                       step="0.01" min="0"
                                       oninput="atualizarPreview()"
                                       required/>
                            </div>
                            <div class="field-group">
                                <label class="field-label" for="fieldStock">Stock inicial</label>
                                <input type="number" id="fieldStock" name="stock"
                                       class="field-input"
                                       placeholder="0"
                                       min="0"
                                       oninput="atualizarPreview()"
                                       required/>
                            </div>
                        </div>

                        <button type="submit" class="btn-criar">Criar produto</button>
                    </form>

                    <a href="produtosAdmin.jsp" class="link-voltar">&larr; Voltar à lista</a>

                </div>
            </div>

            <!-- RIGHT: PREVIEW -->
            <div class="preview-panel">
                <div class="preview-header">Pré-visualização</div>
                <div class="preview-body">
                    <div class="preview-card">
                        <div class="preview-card-img" id="previewImgBox">
                            <svg viewBox="0 0 24 24" id="previewImgIcon"><path d="M21 19V5c0-1.1-.9-2-2-2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2zM8.5 13.5l2.5 3.01L14.5 12l4.5 6H5l3.5-4.5z"/></svg>
                            <img id="previewImg" src="" alt=""/>
                        </div>
                        <div class="preview-card-body">
                            <div class="preview-card-nome" id="previewNome">Nome do produto</div>
                            <div class="preview-card-desc" id="previewDesc">Descrição do produto aparece aqui</div>
                            <div class="preview-card-preco" id="previewPreco">0,00 &euro;</div>
                            <div class="preview-card-stock" id="previewStock">Stock: 0 unidades</div>
                        </div>
                    </div>
                </div>
            </div>

        </div><!-- end page-grid -->
    </main>
</div>

<script>
    function atualizarPreview() {
        const nome  = document.getElementById('fieldNome').value.trim();
        const desc  = document.getElementById('fieldDesc').value.trim();
        const preco = parseFloat(document.getElementById('fieldPreco').value) || 0;
        const stock = parseInt(document.getElementById('fieldStock').value)   || 0;

        document.getElementById('previewNome').textContent  = nome  || 'Nome do produto';
        document.getElementById('previewDesc').textContent  = desc  || 'Descrição do produto aparece aqui';
        document.getElementById('previewPreco').textContent = fmtPreco(preco) + ' €';
        document.getElementById('previewStock').textContent = 'Stock: ' + stock + ' unidades';
    }

    function fmtPreco(val) {
        return val.toFixed(2).replace('.', ',');
    }

    function previewPhoto(input) {
        const file = input.files[0];
        if (!file) return;
        const url = URL.createObjectURL(file);

        const previewImg    = document.getElementById('previewImg');
        const previewIcon   = document.getElementById('previewImgIcon');
        const uploadImg     = document.getElementById('photoPreviewImg');
        const uploadIcon    = document.getElementById('photoIcon');
        const uploadLabel   = document.getElementById('photoLabel');

        uploadImg.src   = url;
        uploadImg.style.display = 'block';
        uploadIcon.style.display = 'none';
        uploadLabel.style.display = 'none';

        previewImg.src  = url;
        previewImg.style.display  = 'block';
        previewIcon.style.display = 'none';
    }

    function validarForm() {
        const nome  = document.getElementById('fieldNome').value.trim();
        const preco = document.getElementById('fieldPreco').value;
        const stock = document.getElementById('fieldStock').value;
        if (!nome || preco === '' || stock === '') {
            alert('Preenche todos os campos obrigatórios.');
            return false;
        }
        return true;
    }
</script>

</body>
</html>

