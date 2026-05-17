<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*" %>
<%@ page import="java.sql.*" %>
<%@ page import="java.security.MessageDigest, java.nio.charset.StandardCharsets" %>
<%@ include file="../basedados/basedados.h" %>
<%!
    private String hashPassword(String plain) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] h = md.digest(plain.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : h) sb.append(String.format("%02x", b));
            return sb.toString();
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }
%>
<%
    // Verificacao da sessao e papel de administrador
    HttpSession sess = request.getSession(false);
    if (sess == null || sess.getAttribute("userId") == null) {
        response.sendRedirect("login.jsp");
        return;
    }
    if (!"administrador".equalsIgnoreCase((String) sess.getAttribute("userRole"))) {
        response.sendRedirect("dashboard.jsp");
        return;
    }
    String adminName = (String) sess.getAttribute("userName");
    String activePage = "utilizadores";

    String successMsg = (String) sess.getAttribute("success");
    if (successMsg != null) sess.removeAttribute("success");
    String errorMsg = null;

    // Processar criacao ou edicao de utilizador
    if ("POST".equalsIgnoreCase(request.getMethod())) {
        String postAction = request.getParameter("action");

        // Guardar dados do utilizador (novo ou edicao)
        if ("guardar".equals(postAction)) {
            String userId = request.getParameter("userId");
            String nome = request.getParameter("nome");
            String email = request.getParameter("email");
            String telefone = request.getParameter("telefone");
            String perfilRaw = request.getParameter("perfil");
            String pw = request.getParameter("password");
            boolean ativo = "true".equalsIgnoreCase(request.getParameter("ativo"));

            String perfil = "cliente";
            if ("funcionario".equals(perfilRaw)) perfil = "funcionario";
            else if ("administrador".equals(perfilRaw)) perfil = "administrador";

            if (nome == null || nome.isBlank() || email == null || email.isBlank()) {
                errorMsg = "Nome e email são obrigatórios.";
            } else {
                try {
                    Connection conn = getConnection();
                    if (userId == null || userId.isBlank()) {
                        if (pw == null || pw.isBlank()) {
                            errorMsg = "Password obrigatória para novo utilizador.";
                            conn.close();
                        } else {
                            PreparedStatement ps = conn.prepareStatement(
                                    "INSERT INTO utilizadores (nome, email, telefone, password_hash, perfil, ativo) VALUES (?,?,?,?,?,?)",
                                    PreparedStatement.RETURN_GENERATED_KEYS);
                            ps.setString(1, nome.trim());
                            ps.setString(2, email.trim());
                            ps.setString(3, telefone != null ? telefone.trim() : null);
                            ps.setString(4, hashPassword(pw));
                            ps.setString(5, perfil);
                            ps.setInt(6, ativo ? 1 : 0);
                            ps.executeUpdate();
                            ResultSet keys = ps.getGeneratedKeys();
                            int newId = keys.next() ? keys.getInt(1) : -1;
                            keys.close();
                            ps.close();
                            if (newId > 0) {
                                ps = conn.prepareStatement("INSERT INTO carteira (id_utilizador, saldo, is_loja) VALUES (?,0,0)");
                                ps.setInt(1, newId);
                                ps.executeUpdate();
                                ps.close();
                            }
                            conn.close();
                            logAuditoria("Utilizador", "criado", "Utilizador criado: " + nome.trim() + " (" + perfil + ")", newId > 0 ? newId : null, (Integer) sess.getAttribute("userId"));
                            sess.setAttribute("success", "Utilizador criado com sucesso.");
                            response.sendRedirect("utilizadoresAdmin.jsp?userId=" + newId);
                            return;
                        }
                    } else {
                        if (pw != null && !pw.isBlank()) {
                            PreparedStatement ps = conn.prepareStatement(
                                    "UPDATE utilizadores SET nome=?, email=?, telefone=?, perfil=?, ativo=?, password_hash=? WHERE id_utilizador=?");
                            ps.setString(1, nome.trim());
                            ps.setString(2, email.trim());
                            ps.setString(3, telefone != null ? telefone.trim() : null);
                            ps.setString(4, perfil);
                            ps.setInt(5, ativo ? 1 : 0);
                            ps.setString(6, hashPassword(pw));
                            ps.setInt(7, Integer.parseInt(userId));
                            ps.executeUpdate();
                            closeAll(null, ps, conn);
                        } else {
                            PreparedStatement ps = conn.prepareStatement(
                                    "UPDATE utilizadores SET nome=?, email=?, telefone=?, perfil=?, ativo=? WHERE id_utilizador=?");
                            ps.setString(1, nome.trim());
                            ps.setString(2, email.trim());
                            ps.setString(3, telefone != null ? telefone.trim() : null);
                            ps.setString(4, perfil);
                            ps.setInt(5, ativo ? 1 : 0);
                            ps.setInt(6, Integer.parseInt(userId));
                            ps.executeUpdate();
                            closeAll(null, ps, conn);
                        }
                        logAuditoria("Utilizador", "editado", "Utilizador editado: " + nome.trim() + " (id:" + userId + ")", Integer.parseInt(userId), (Integer) sess.getAttribute("userId"));
                        sess.setAttribute("success", "Utilizador atualizado.");
                        response.sendRedirect("utilizadoresAdmin.jsp?userId=" + userId);
                        return;
                    }
                } catch (Exception e) {
                    errorMsg = "Erro: " + e.getMessage();
                }
            }
        } else if ("toggleAtivo".equals(postAction)) {
            String uid = request.getParameter("userId");
            try {
                Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement("UPDATE utilizadores SET ativo = 1 - ativo WHERE id_utilizador = ?");
                ps.setInt(1, Integer.parseInt(uid));
                ps.executeUpdate();
                closeAll(null, ps, conn);
                logAuditoria("Utilizador", "ativo alterado", "Estado do utilizador alterado (id:" + uid + ")", Integer.parseInt(uid), (Integer) sess.getAttribute("userId"));
                sess.setAttribute("success", "Estado do utilizador alterado.");
                response.sendRedirect("utilizadoresAdmin.jsp?userId=" + uid);
                return;
            } catch (Exception e) {
                errorMsg = "Erro: " + e.getMessage();
            }
        }
    }

    // {id, nome, email, telefone, perfil, ativo, saldo_cents, num_encomendas, membro_desde}
    List<Object[]> users = new ArrayList<>();

    Connection conn = null;
    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        conn = getConnection();
        ps = conn.prepareStatement(
                "SELECT u.id_utilizador, u.nome, u.email, COALESCE(u.telefone,'') as telefone," +
                        "       u.perfil, u.ativo, COALESCE(c.saldo,0) as saldo," +
                        "       COUNT(DISTINCT e.id_encomenda) as num_encomendas," +
                        "       DATE_FORMAT(u.data_registo,'%d/%m/%Y') as membro_desde" +
                        " FROM utilizadores u" +
                        " LEFT JOIN carteira c ON c.id_utilizador = u.id_utilizador AND c.is_loja = 0" +
                        " LEFT JOIN encomenda e ON e.id_utilizador = u.id_utilizador" +
                        " GROUP BY u.id_utilizador, u.nome, u.email, u.telefone, u.perfil, u.ativo, c.saldo, u.data_registo" +
                        " ORDER BY u.id_utilizador");
        rs = ps.executeQuery();
        while (rs.next()) {
            double saldo = rs.getDouble("saldo");
            int saldoCents = (int) (saldo * 100);
            boolean ativo = rs.getInt("ativo") == 1;
            String perfil = rs.getString("perfil");
            String perfilDisplay = "Cliente";
            if ("funcionario".equalsIgnoreCase(perfil)) perfilDisplay = "Funcionário";
            else if ("administrador".equalsIgnoreCase(perfil)) perfilDisplay = "Admin";
            users.add(new Object[]{
                    String.valueOf(rs.getInt("id_utilizador")),
                    rs.getString("nome"),
                    rs.getString("email"),
                    rs.getString("telefone"),
                    perfilDisplay,
                    ativo,
                    saldoCents,
                    rs.getInt("num_encomendas"),
                    rs.getString("membro_desde")
            });
        }
    } catch (Exception e) {
        errorMsg = "Erro ao carregar utilizadores: " + e.getMessage();
    } finally {
        closeAll(rs, ps, conn);
    }

    String selectedId = request.getParameter("userId");
    if ((selectedId == null || selectedId.isEmpty()) && !users.isEmpty()) {
        selectedId = (String) users.get(0)[0];
    }
    if (selectedId == null) selectedId = "";

    String selNome = "";
    String selEmail = "";
    String selTel = "";
    String selPerfil = "";
    boolean selAtivo = true;
    int selSaldo = 0;
    int selEnc = 0;
    String selMembro = "";

    for (Object[] u : users) {
        if (u[0].equals(selectedId)) {
            selNome = (String) u[1];
            selEmail = (String) u[2];
            selTel = (String) u[3];
            selPerfil = (String) u[4];
            selAtivo = (Boolean) u[5];
            selSaldo = (Integer) u[6];
            selEnc = (Integer) u[7];
            selMembro = (String) u[8];
            break;
        }
    }
%>
<!DOCTYPE html>
<html lang="pt">
<head>
    <meta charset="UTF-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <title>utilizadoresAdmin</title>
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

        /* Users table */
        .users-table {
            width: 100%;
            border-collapse: collapse;
        }

        .users-table th {
            padding: 9px 14px;
            font-size: .71rem;
            font-weight: 700;
            letter-spacing: .6px;
            text-transform: uppercase;
            color: #555;
            text-align: left;
            border-bottom: 1px solid #333;
            background: #252525;
        }

        .users-table td {
            padding: 11px 14px;
            font-size: .86rem;
            color: #bbb;
            border-bottom: 1px solid #272727;
            vertical-align: middle;
        }

        .users-table tr:last-child td {
            border-bottom: none;
        }

        .users-table tr.selected td {
            background: rgba(0, 206, 134, .05);
        }

        .users-table tr:not(.selected):hover td {
            background: rgba(255, 255, 255, .02);
            cursor: pointer;
        }

        .user-nome {
            font-weight: 600;
            color: #ddd;
        }

        .user-email {
            color: #888;
            font-size: .83rem;
        }

        /* Badges */
        .badge {
            display: inline-block;
            padding: 3px 10px;
            border-radius: 20px;
            font-size: .71rem;
            font-weight: 700;
        }

        .badge-cliente {
            background: rgba(139, 92, 246, .15);
            color: #a78bfa;
            border: 1px solid rgba(139, 92, 246, .3);
        }

        .badge-funcionario {
            background: rgba(245, 158, 11, .13);
            color: #fbbf24;
            border: 1px solid rgba(245, 158, 11, .3);
        }

        .badge-admin {
            background: rgba(59, 130, 246, .13);
            color: #60a5fa;
            border: 1px solid rgba(59, 130, 246, .3);
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

        /* Action buttons */
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
            margin: 12px 16px 0;
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

        /* Form fields */
        .field-group {
            padding: 0 16px 12px;
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
            font-family: inherit;
        }

        .field-input:focus {
            border-color: #00CE86;
            box-shadow: 0 0 0 3px rgba(0, 206, 134, .1);
        }

        .field-select {
            width: 100%;
            background: #1a1a1a;
            border: 1px solid #3a3a3a;
            border-radius: 7px;
            color: #fff;
            font-size: .88rem;
            padding: 8px 11px;
            outline: none;
            cursor: pointer;
            transition: border-color .2s;
            appearance: auto;
        }

        .field-select:focus {
            border-color: #00CE86;
        }

        .field-select option {
            background: #1a1a1a;
        }

        .form-top-gap {
            height: 14px;
        }

        /* Action buttons in panel */
        .edit-actions {
            padding: 4px 16px 16px;
            display: flex;
            flex-direction: column;
            gap: 8px;
            border-top: 1px solid #2a2a2a;
            padding-top: 14px;
            margin-top: 4px;
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

        .btn-inativar-user {
            width: 100%;
            padding: 10px;
            background: rgba(180, 30, 30, .15);
            border: 1px solid #7a3030;
            color: #e07070;
            border-radius: 7px;
            font-size: .88rem;
            font-weight: 700;
            cursor: pointer;
            transition: background .2s, border-color .2s;
        }

        .btn-inativar-user:hover {
            background: rgba(220, 60, 60, .18);
            border-color: #e05555;
        }

        /* Resumo section */
        .resumo-section {
            margin: 0 16px 16px;
            border-top: 1px solid #2a2a2a;
            padding-top: 14px;
        }

        .resumo-title {
            font-size: .78rem;
            font-weight: 700;
            color: #666;
            letter-spacing: .6px;
            text-transform: uppercase;
            margin-bottom: 10px;
        }

        .resumo-row {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 5px 0;
            font-size: .84rem;
            border-bottom: 1px solid #2a2a2a;
        }

        .resumo-row:last-child {
            border-bottom: none;
        }

        .resumo-label {
            color: #777;
        }

        .resumo-value {
            color: #ccc;
            font-weight: 600;
        }

        .resumo-value.green {
            color: #00CE86;
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

            .users-table th:nth-child(2),
            .users-table td:nth-child(2) {
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
            Olá, <strong style="color:#e0e0e0;margin-left:4px;"><%= adminName %>
        </strong>
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
                    <svg viewBox="0 0 24 24">
                        <path d="M3 13h8V3H3v10zm0 8h8v-6H3v6zm10 0h8V11h-8v10zm0-18v6h8V3h-8z"/>
                    </svg>
                    <span>Dashboard</span>
                </a>
            </li>
            <li>
                <a href="encomendasAdmin.jsp" class="<%= "encomendas".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24">
                        <path d="M20 6h-2.18A3 3 0 0 0 15 4H9a3 3 0 0 0-2.82 2H4c-1.1 0-2 .9-2 2v11c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-11 0h6c.55 0 1 .45 1 1s-.45 1-1 1H9c-.55 0-1-.45-1-1s.45-1 1-1zM8 13h8v1.5H8V13zm0 3h5v1.5H8V16z"/>
                    </svg>
                    <span>Encomendas</span>
                </a>
            </li>
            <li>
                <a href="saldoClientesAdmin.jsp" class="<%= "saldo".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24">
                        <path d="M21 7H3c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V9c0-1.1-.9-2-2-2zm-1 12H4V9h16v10zm-5-5a2 2 0 1 1 4 0 2 2 0 0 1-4 0zM3 5h16V3H3z"/>
                    </svg>
                    <span>Saldo clientes</span>
                </a>
            </li>
            <li>
                <a href="produtosAdmin.jsp" class="<%= "produtos".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24">
                        <path d="M20 2H4c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm-5 12H9v-2h6v2zm2-4H7V8h10v2z"/>
                    </svg>
                    <span>Produtos</span>
                </a>
            </li>
            <li>
                <a href="utilizadoresAdmin.jsp" class="<%= "utilizadores".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24">
                        <path d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z"/>
                    </svg>
                    <span>Utilizadores</span>
                </a>
            </li>
            <li>
                <%-- TODO: criar promocoesAdmin.jsp --%>
                <a href="promocoesAdmin.jsp" class="<%= "promocoes".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24">
                        <path d="M21.41 11.58l-9-9C12.05 2.22 11.55 2 11 2H4c-1.1 0-2 .9-2 2v7c0 .55.22 1.05.59 1.42l9 9c.36.36.86.58 1.41.58.55 0 1.05-.22 1.41-.59l7-7c.37-.36.59-.86.59-1.41 0-.55-.23-1.06-.59-1.42zM5.5 7C4.67 7 4 6.33 4 5.5S4.67 4 5.5 4 7 4.67 7 5.5 6.33 7 5.5 7z"/>
                    </svg>
                    <span>Promoções</span>
                </a>
            </li>
            <li>
                <a href="auditoriaAdmin.jsp" class="<%= "auditoria".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24">
                        <path d="M9 17H7v-7h2v7zm4 0h-2V7h2v10zm4 0h-2v-4h2v4zm2 2H5V5h14v14zm0-16H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2z"/>
                    </svg>
                    <span>Auditoria</span>
                </a>
            </li>
            <div class="sidebar-divider"></div>
            <li>
                <%-- TODO: criar perfilAdmin.jsp --%>
                <a href="perfilAdmin.jsp" class="<%= "perfil".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24">
                        <path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/>
                    </svg>
                    <span>Perfil</span>
                </a>
            </li>
        </ul>
    </aside>

    <!-- MAIN -->
    <main class="main-content">

        <div class="page-grid">

            <!-- LEFT: USERS TABLE -->
            <div class="panel">
                <div class="panel-header">
                    <div class="panel-title">
                        <svg viewBox="0 0 24 24">
                            <path d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z"/>
                        </svg>
                        Gestão de utilizadores
                    </div>
                    <%-- TODO: criar novoUtilizadorAdmin.jsp ou modal inline --%>
                    <a href="novoUtilizadorAdmin.jsp" class="btn-novo">
                        <svg viewBox="0 0 24 24" style="width:13px;height:13px;fill:currentColor;">
                            <path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z"/>
                        </svg>
                        Novo utilizador
                    </a>
                </div>

                <!-- Filters -->
                <div class="filter-bar">
                    <div class="search-wrap">
                        <svg viewBox="0 0 24 24">
                            <path d="M15.5 14h-.79l-.28-.27A6.47 6.47 0 0 0 16 9.5 6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z"/>
                        </svg>
                        <input type="text" id="searchInput" class="search-input"
                               placeholder="Pesquisar..."
                               oninput="filterTable()"/>
                    </div>
                    <select id="filterPerfil" class="filter-select" onchange="filterTable()">
                        <option value="">Todos os perfis</option>
                        <option value="cliente">Cliente</option>
                        <option value="funcionário">Funcionário</option>
                        <option value="admin">Admin</option>
                    </select>
                    <select id="filterEstado" class="filter-select" onchange="filterTable()">
                        <option value="">Todos os estados</option>
                        <option value="ativo">Ativo</option>
                        <option value="inativo">Inativo</option>
                    </select>
                </div>

                <!-- Table -->
                <table class="users-table" id="usersTable">
                    <thead>
                    <tr>
                        <th>Nome</th>
                        <th>Email</th>
                        <th>Perfil</th>
                        <th>Estado</th>
                        <th>Ações</th>
                    </tr>
                    </thead>
                    <tbody>
                    <%
                        for (Object[] u : users) {
                            String uid = (String) u[0];
                            String unome = (String) u[1];
                            String uemail = (String) u[2];
                            String utel = (String) u[3];
                            String uperfil = (String) u[4];
                            boolean uativo = (Boolean) u[5];
                            int usaldo = (Integer) u[6];
                            int uenc = (Integer) u[7];
                            String umembro = (String) u[8];

                            String saldoStr = String.format("%d,%02d €", usaldo / 100, usaldo % 100);
                            boolean isSelected = uid.equals(selectedId);

                            String perfilClass = "badge-cliente";
                            if ("Funcionário".equals(uperfil)) perfilClass = "badge-funcionario";
                            else if ("Admin".equals(uperfil)) perfilClass = "badge-admin";
                    %>
                    <tr class="<%= isSelected ? "selected" : "" %>"
                        data-nome="<%= unome.toLowerCase() %>"
                        data-perfil="<%= uperfil.toLowerCase() %>"
                        data-ativo="<%= uativo ? "ativo" : "inativo" %>"
                        onclick="selectUser('<%= uid %>','<%= unome %>','<%= uemail %>','<%= utel %>','<%= uperfil %>',<%= uativo %>,<%= usaldo %>,'<%= saldoStr %>',<%= uenc %>,'<%= umembro %>')">
                        <td class="user-nome"><%= unome %>
                        </td>
                        <td class="user-email"><%= uemail %>
                        </td>
                        <td><span class="badge <%= perfilClass %>"><%= uperfil %></span></td>
                        <td><span
                                class="badge <%= uativo ? "badge-ativo" : "badge-inativo" %>"><%= uativo ? "Ativo" : "Inativo" %></span>
                        </td>
                        <td onclick="event.stopPropagation()">
                            <div class="action-btns">
                                <button class="btn-editar"
                                        onclick="selectUser('<%= uid %>','<%= unome %>','<%= uemail %>','<%= utel %>','<%= uperfil %>',<%= uativo %>,<%= usaldo %>,'<%= saldoStr %>',<%= uenc %>,'<%= umembro %>')">
                                    Editar
                                </button>
                                <% if (!"Admin".equals(uperfil)) { %>
                                <form method="post" action="utilizadoresAdmin.jsp" style="display:inline;margin:0">
                                    <input type="hidden" name="action" value="toggleAtivo"/>
                                    <input type="hidden" name="userId" value="<%= uid %>"/>
                                    <button type="submit" class="<%= uativo ? "btn-inativar" : "btn-ativar" %>"
                                            onclick="return confirm('<%= uativo ? "Inativar" : "Ativar" %> <%= unome %>?')">
                                        <%= uativo ? "Inativar" : "Ativar" %>
                                    </button>
                                </form>
                                <% } %>
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
                    <svg viewBox="0 0 24 24">
                        <path d="M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25zM20.71 7.04a1 1 0 0 0 0-1.41l-2.34-2.34a1 1 0 0 0-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83z"/>
                    </svg>
                    <span class="edit-panel-title" id="editPanelTitle">Editar utilizador</span>
                </div>

                <!-- Alert -->
                <% if (successMsg != null && !successMsg.isEmpty()) { %>
                <div class="panel-alert panel-alert-success">
                    <svg viewBox="0 0 24 24" fill="#00CE86">
                        <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 14l-4-4 1.41-1.41L10 13.17l6.59-6.59L18 8l-8 8z"/>
                    </svg>
                    <%= successMsg %>
                </div>
                <% } %>
                <% if (errorMsg != null && !errorMsg.isEmpty()) { %>
                <div class="panel-alert panel-alert-error">
                    <svg viewBox="0 0 24 24" fill="#f08080">
                        <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/>
                    </svg>
                    <%= errorMsg %>
                </div>
                <% } %>

                <div id="editFormArea">
                    <%
                        String initSaldo = String.format("%d,%02d €", selSaldo / 100, selSaldo % 100);
                    %>

                    <form action="utilizadoresAdmin.jsp" method="post"
                          onsubmit="return confirm('Guardar alterações?')">
                        <input type="hidden" name="action" value="guardar"/>
                        <input type="hidden" id="hiddenId" name="userId" value="<%= selectedId %>"/>
                        <input type="hidden" id="hiddenAtivo" name="ativo" value="<%= selAtivo %>"/>

                        <div class="form-top-gap"></div>

                        <div class="field-group">
                            <label class="field-label">Nome completo</label>
                            <input type="text" name="nome" id="fieldNome"
                                   class="field-input"
                                   value="<%= selNome %>" required/>
                        </div>

                        <div class="field-group">
                            <label class="field-label">Email</label>
                            <input type="email" name="email" id="fieldEmail"
                                   class="field-input"
                                   value="<%= selEmail %>" required/>
                        </div>

                        <div class="field-group">
                            <label class="field-label">Telefone</label>
                            <input type="text" name="telefone" id="fieldTel"
                                   class="field-input"
                                   value="<%= selTel %>"/>
                        </div>

                        <div class="field-group">
                            <label class="field-label">Perfil</label>
                            <select name="perfil" id="fieldPerfil" class="field-select">
                                <option value="cliente"        <%= "Cliente".equals(selPerfil) ? "selected" : "" %>>
                                    Cliente
                                </option>
                                <option value="funcionario"    <%= "Funcionário".equals(selPerfil) ? "selected" : "" %>>
                                    Funcionário
                                </option>
                                <option value="administrador"  <%= "Admin".equals(selPerfil) ? "selected" : "" %>>
                                    Admin
                                </option>
                            </select>
                        </div>

                        <div class="field-group">
                            <label class="field-label">Nova password (opcional)</label>
                            <input type="password" name="password" id="fieldPass"
                                   class="field-input"
                                   placeholder="••••••"/>
                        </div>

                        <div class="edit-actions">
                            <button type="submit" class="btn-guardar">Guardar alterações</button>
                        </div>
                    </form>
                    <% if (!"Admin".equals(selPerfil) && !selectedId.isEmpty()) { %>
                    <div style="padding: 0 16px 16px;">
                        <form method="post" action="utilizadoresAdmin.jsp" style="margin:0"
                              onsubmit="return confirm('<%= selAtivo ? "Inativar" : "Ativar" %> utilizador?')">
                            <input type="hidden" name="action" value="toggleAtivo"/>
                            <input type="hidden" name="userId" value="<%= selectedId %>"/>
                            <button type="submit" id="btnToggleEstado" class="btn-inativar-user">
                                <%= selAtivo ? "Inativar utilizador" : "Ativar utilizador" %>
                            </button>
                        </form>
                    </div>
                    <% } %>

                    <!-- Resumo -->
                    <div class="resumo-section" id="resumoSection">
                        <div class="resumo-title">Resumo</div>
                        <div class="resumo-row">
                            <span class="resumo-label">Saldo</span>
                            <span class="resumo-value green" id="resumoSaldo"><%= initSaldo %></span>
                        </div>
                        <div class="resumo-row">
                            <span class="resumo-label">Encomendas</span>
                            <span class="resumo-value" id="resumoEnc"><%= selEnc %></span>
                        </div>
                        <div class="resumo-row">
                            <span class="resumo-label">Membro desde</span>
                            <span class="resumo-value" id="resumoMembro"><%= selMembro %></span>
                        </div>
                    </div>

                </div><!-- end editFormArea -->
            </div><!-- end edit-panel -->

        </div><!-- end page-grid -->
    </main>
</div>

<script>
    function selectUser(id, nome, email, tel, perfil, ativo, saldoCents, saldoStr, numEnc, membro) {
        document.getElementById('hiddenId').value = id;
        document.getElementById('hiddenAtivo').value = ativo;
        document.getElementById('fieldNome').value = nome;
        document.getElementById('fieldEmail').value = email;
        document.getElementById('fieldTel').value = tel;
        document.getElementById('fieldPass').value = '';

        const sel = document.getElementById('fieldPerfil');
        for (let i = 0; i < sel.options.length; i++) {
            sel.options[i].selected = sel.options[i].value === perfil;
        }

        const btn = document.getElementById('btnToggleEstado');
        if (btn) {
            btn.textContent = ativo ? 'Inativar utilizador' : 'Ativar utilizador';
            btn.onclick = () => confirm((ativo ? 'Inativar ' : 'Ativar ') + nome + '?');
        }

        document.getElementById('resumoSaldo').textContent = saldoStr;
        document.getElementById('resumoEnc').textContent = numEnc;
        document.getElementById('resumoMembro').textContent = membro;

        document.querySelectorAll('.users-table tbody tr').forEach(row => row.classList.remove('selected'));
        document.querySelectorAll('.users-table tbody tr').forEach(row => {
            if (row.dataset.nome === nome.toLowerCase()) row.classList.add('selected');
        });
    }

    function filterTable() {
        const q = document.getElementById('searchInput').value.toLowerCase();
        const perfil = document.getElementById('filterPerfil').value.toLowerCase();
        const estado = document.getElementById('filterEstado').value.toLowerCase();
        const rows = document.querySelectorAll('#usersTable tbody tr');
        rows.forEach(row => {
            const nome = row.dataset.nome || '';
            const rperf = row.dataset.perfil || '';
            const rativo = row.dataset.ativo || '';
            const matchQ = nome.includes(q);
            const matchP = !perfil || rperf === perfil;
            const matchE = !estado || rativo === estado;
            row.style.display = (matchQ && matchP && matchE) ? '' : 'none';
        });
    }
</script>

</body>
</html>

