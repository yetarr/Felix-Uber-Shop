<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*" %>
<%@ page import="java.sql.*" %>
<%@ include file="../basedados/basedados.h" %>
<%
    HttpSession sess = request.getSession(false);
    if (sess == null || sess.getAttribute("userId") == null) { response.sendRedirect("login.jsp"); return; }
    if (!"administrador".equals(sess.getAttribute("userRole"))) { response.sendRedirect("dashboard.jsp"); return; }
    String adminName = (String) sess.getAttribute("userName");
    String orderId   = request.getParameter("id");
    boolean isNova   = (orderId == null || "true".equals(request.getParameter("novo")));

    String orderCliente = "";
    String orderData    = "";
    String orderStatus  = "pendente";
    String saldoCliente = "0,00";
    List<Object[]> catalogue = new ArrayList<>();

    Connection _conn6 = null;
    PreparedStatement _ps6 = null;
    ResultSet _rs6 = null;
    try {
        _conn6 = getConnection();
        int orderIdInt = 0;
        if (!isNova && orderId != null) {
            try { orderIdInt = Integer.parseInt(orderId); } catch (Exception _ex6) {}
        }

        int clientUserId = 0;
        if (!isNova && orderIdInt > 0) {
            // Order details + client
            _ps6 = _conn6.prepareStatement(
                "SELECT e.estado, e.data_encomenda, u.nome, u.id_utilizador " +
                "FROM encomenda e JOIN utilizadores u ON u.id_utilizador=e.id_utilizador " +
                "WHERE e.id_encomenda=?");
            _ps6.setInt(1, orderIdInt);
            _rs6 = _ps6.executeQuery();
            if (_rs6.next()) {
                orderStatus  = _rs6.getString("estado");
                orderData    = String.valueOf(_rs6.getTimestamp("data_encomenda"));
                orderCliente = _rs6.getString("nome");
                clientUserId = _rs6.getInt("id_utilizador");
            }
            closeAll(_rs6, _ps6, null);

            // Client wallet balance
            if (clientUserId > 0) {
                _ps6 = _conn6.prepareStatement("SELECT saldo FROM carteira WHERE id_utilizador=?");
                _ps6.setInt(1, clientUserId);
                _rs6 = _ps6.executeQuery();
                if (_rs6.next()) {
                    saldoCliente = String.format("%.2f", _rs6.getDouble("saldo")).replace(".", ",");
                }
                closeAll(_rs6, _ps6, null);
            }
        }

        // Catalogue with current order quantities
        _ps6 = _conn6.prepareStatement(
            "SELECT p.id_produto, p.nome, p.categoria, CAST(p.preco*100 AS SIGNED) as preco_cents, " +
            "0 as desconto, COALESCE(ep.quantidade,0) as qty_atual, CAST(p.preco*100 AS SIGNED) as preco_orig " +
            "FROM produtos p " +
            "LEFT JOIN encomenda_produto ep ON ep.id_produto=p.id_produto AND ep.id_encomenda=? " +
            "WHERE p.ativo=1 ORDER BY p.nome");
        _ps6.setInt(1, orderIdInt);
        _rs6 = _ps6.executeQuery();
        while (_rs6.next()) {
            catalogue.add(new Object[]{
                String.valueOf(_rs6.getInt("id_produto")),
                _rs6.getString("nome"),
                _rs6.getString("categoria") != null ? _rs6.getString("categoria") : "",
                (int) _rs6.getLong("preco_cents"),
                0,
                _rs6.getInt("qty_atual"),
                (int) _rs6.getLong("preco_orig")
            });
        }
    } catch (Exception _e6) {
        // page renders with empty data on error
    } finally {
        closeAll(_rs6, _ps6, _conn6);
    }

    String successMsg = (String) sess.getAttribute("success");
    if (successMsg != null) sess.removeAttribute("success");
    String errorMsg = null;

    if ("POST".equalsIgnoreCase(request.getMethod())) {
        String orderIdStr = request.getParameter("orderId");
        String novoEstado = request.getParameter("estado");
        String clienteIdStr = request.getParameter("clienteId");
        try {
            Connection conn = getConnection();
            PreparedStatement ps;
            ResultSet rs;
            int oid;

            if (orderIdStr == null || orderIdStr.isEmpty()) {
                // Create new order
                int cid = Integer.parseInt(clienteIdStr);
                String codigoUnico = "FUS-" + System.currentTimeMillis();
                ps = conn.prepareStatement(
                    "INSERT INTO encomenda (codigo_unico, id_utilizador, estado, total) VALUES (?, ?, 'pendente', 0)",
                    java.sql.Statement.RETURN_GENERATED_KEYS);
                ps.setString(1, codigoUnico); ps.setInt(2, cid);
                ps.executeUpdate();
                rs = ps.getGeneratedKeys(); oid = rs.next() ? rs.getInt(1) : -1; rs.close(); ps.close();
                if (oid < 0) { conn.close(); errorMsg = "Erro ao criar encomenda."; }
                else {
                    double total = 0;
                    for (java.util.Enumeration<String> params = request.getParameterNames(); params.hasMoreElements();) {
                        String param = params.nextElement();
                        if (param.startsWith("produto_")) {
                            int pid = Integer.parseInt(param.substring("produto_".length()));
                            int qty = Integer.parseInt(request.getParameter(param));
                            if (qty > 0) {
                                ps = conn.prepareStatement("SELECT preco FROM produtos WHERE id_produto = ?");
                                ps.setInt(1, pid); rs = ps.executeQuery();
                                double preco = rs.next() ? rs.getDouble("preco") : 0; rs.close(); ps.close();
                                ps = conn.prepareStatement("INSERT INTO encomenda_produto (id_encomenda, id_produto, quantidade, preco_unitario) VALUES (?,?,?,?)");
                                ps.setInt(1, oid); ps.setInt(2, pid); ps.setInt(3, qty); ps.setDouble(4, preco);
                                ps.executeUpdate(); ps.close();
                                total += preco * qty;
                            }
                        }
                    }
                    ps = conn.prepareStatement("UPDATE encomenda SET total = ? WHERE id_encomenda = ?");
                    ps.setDouble(1, total); ps.setInt(2, oid); ps.executeUpdate(); closeAll(null, ps, conn);
                    sess.setAttribute("success", "Encomenda criada com sucesso.");
                    response.sendRedirect("criarEditarEncomendaAdmin.jsp?id=" + oid); return;
                }
            } else {
                oid = Integer.parseInt(orderIdStr);
                ps = conn.prepareStatement(
                    "SELECT e.estado, e.total, e.id_utilizador FROM encomenda e WHERE e.id_encomenda = ?");
                ps.setInt(1, oid); rs = ps.executeQuery();
                if (!rs.next()) { rs.close(); ps.close(); conn.close(); errorMsg = "Encomenda não encontrada."; }
                else {
                    String estadoAnterior = rs.getString("estado");
                    int clienteUserId2 = rs.getInt("id_utilizador");
                    rs.close(); ps.close();

                    ps = conn.prepareStatement("DELETE FROM encomenda_produto WHERE id_encomenda = ?");
                    ps.setInt(1, oid); ps.executeUpdate(); ps.close();
                    double total = 0;
                    for (java.util.Enumeration<String> params = request.getParameterNames(); params.hasMoreElements();) {
                        String param = params.nextElement();
                        if (param.startsWith("produto_")) {
                            int pid = Integer.parseInt(param.substring("produto_".length()));
                            int qty = Integer.parseInt(request.getParameter(param));
                            if (qty > 0) {
                                ps = conn.prepareStatement("SELECT preco FROM produtos WHERE id_produto = ?");
                                ps.setInt(1, pid); rs = ps.executeQuery();
                                double preco = rs.next() ? rs.getDouble("preco") : 0; rs.close(); ps.close();
                                ps = conn.prepareStatement("INSERT INTO encomenda_produto (id_encomenda, id_produto, quantidade, preco_unitario) VALUES (?,?,?,?)");
                                ps.setInt(1, oid); ps.setInt(2, pid); ps.setInt(3, qty); ps.setDouble(4, preco);
                                ps.executeUpdate(); ps.close();
                                total += preco * qty;
                            }
                        }
                    }
                    ps = conn.prepareStatement("UPDATE encomenda SET total = ? WHERE id_encomenda = ?");
                    ps.setDouble(1, total); ps.setInt(2, oid); ps.executeUpdate(); ps.close();

                    if (novoEstado != null && !novoEstado.equals(estadoAnterior)) {
                        if ("pronto".equals(novoEstado) && !"pronto".equals(estadoAnterior)) {
                            ps = conn.prepareStatement("SELECT c.id_carteira, c.saldo FROM carteira c WHERE c.id_utilizador = ?");
                            ps.setInt(1, clienteUserId2); rs = ps.executeQuery();
                            int cCart = rs.next() ? rs.getInt("id_carteira") : -1;
                            double saldoC = rs.getDouble("saldo"); rs.close(); ps.close();
                            ps = conn.prepareStatement("SELECT id_carteira FROM carteira WHERE is_loja = 1 LIMIT 1");
                            rs = ps.executeQuery(); int lCart = rs.next() ? rs.getInt("id_carteira") : -1; rs.close(); ps.close();
                            if (saldoC < total) { conn.close(); errorMsg = "Saldo insuficiente do cliente para confirmar."; }
                            else {
                                ps = conn.prepareStatement("UPDATE carteira SET saldo = saldo - ? WHERE id_carteira = ?");
                                ps.setDouble(1, total); ps.setInt(2, cCart); ps.executeUpdate(); ps.close();
                                ps = conn.prepareStatement("UPDATE carteira SET saldo = saldo + ? WHERE id_carteira = ?");
                                ps.setDouble(1, total); ps.setInt(2, lCart); ps.executeUpdate(); ps.close();
                                ps = conn.prepareStatement("INSERT INTO auditoria_carteira (id_carteira_origem, id_carteira_destino, valor, tipo_operacao, descricao, id_encomenda) VALUES (?,?,?,'pagamento',?,?)");
                                ps.setInt(1, cCart); ps.setInt(2, lCart); ps.setDouble(3, total);
                                ps.setString(4, "Pagamento encomenda #" + oid); ps.setInt(5, oid);
                                ps.executeUpdate(); ps.close();
                                ps = conn.prepareStatement("UPDATE encomenda SET estado = ? WHERE id_encomenda = ?");
                                ps.setString(1, novoEstado); ps.setInt(2, oid); ps.executeUpdate(); closeAll(null, ps, conn);
                                sess.setAttribute("success", "Encomenda confirmada e pagamento processado.");
                                response.sendRedirect("criarEditarEncomendaAdmin.jsp?id=" + oid); return;
                            }
                        } else if ("cancelado".equals(novoEstado) && "pronto".equals(estadoAnterior)) {
                            ps = conn.prepareStatement("SELECT c.id_carteira FROM carteira c WHERE c.id_utilizador = ?");
                            ps.setInt(1, clienteUserId2); rs = ps.executeQuery();
                            int cCart = rs.next() ? rs.getInt("id_carteira") : -1; rs.close(); ps.close();
                            ps = conn.prepareStatement("SELECT id_carteira FROM carteira WHERE is_loja = 1 LIMIT 1");
                            rs = ps.executeQuery(); int lCart = rs.next() ? rs.getInt("id_carteira") : -1; rs.close(); ps.close();
                            ps = conn.prepareStatement("UPDATE carteira SET saldo = saldo + ? WHERE id_carteira = ?");
                            ps.setDouble(1, total); ps.setInt(2, cCart); ps.executeUpdate(); ps.close();
                            ps = conn.prepareStatement("UPDATE carteira SET saldo = saldo - ? WHERE id_carteira = ?");
                            ps.setDouble(1, total); ps.setInt(2, lCart); ps.executeUpdate(); ps.close();
                            ps = conn.prepareStatement("INSERT INTO auditoria_carteira (id_carteira_origem, id_carteira_destino, valor, tipo_operacao, descricao, id_encomenda) VALUES (?,?,?,'reembolso',?,?)");
                            ps.setInt(1, lCart); ps.setInt(2, cCart); ps.setDouble(3, total);
                            ps.setString(4, "Reembolso encomenda cancelada #" + oid); ps.setInt(5, oid);
                            ps.executeUpdate(); ps.close();
                            ps = conn.prepareStatement("UPDATE encomenda SET estado = ? WHERE id_encomenda = ?");
                            ps.setString(1, novoEstado); ps.setInt(2, oid); ps.executeUpdate(); closeAll(null, ps, conn);
                            sess.setAttribute("success", "Encomenda cancelada e reembolso processado.");
                            response.sendRedirect("criarEditarEncomendaAdmin.jsp?id=" + oid); return;
                        } else {
                            ps = conn.prepareStatement("UPDATE encomenda SET estado = ? WHERE id_encomenda = ?");
                            ps.setString(1, novoEstado); ps.setInt(2, oid); ps.executeUpdate(); closeAll(null, ps, conn);
                            sess.setAttribute("success", "Encomenda atualizada.");
                            response.sendRedirect("criarEditarEncomendaAdmin.jsp?id=" + oid); return;
                        }
                    } else {
                        conn.close();
                        sess.setAttribute("success", "Encomenda atualizada com sucesso.");
                        response.sendRedirect("criarEditarEncomendaAdmin.jsp?id=" + oid); return;
                    }
                }
            }
        } catch (Exception e) { errorMsg = "Erro: " + e.getMessage(); }
    }

    String activePage = "encomendas";
%>
<!DOCTYPE html>
<html lang="pt">
<head>
    <meta charset="UTF-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <title>criar/editar encomendaAdmin</title>
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
            padding: 24px 24px 48px;
            overflow-y: auto;
            min-width: 0;
        }

        /* ── ALERTS ──────────────────────────────────────── */
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

        /* ── EDITOR GRID ─────────────────────────────────── */
        .editor-grid {
            display: grid;
            grid-template-columns: 1fr 285px;
            gap: 18px;
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

        /* ── PRODUCT GRID ────────────────────────────────── */
        .product-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
            gap: 12px;
            padding: 16px;
            max-height: calc(100vh - 160px);
            overflow-y: auto;
        }

        .product-card {
            background: #1e1e1e;
            border: 2px solid #333;
            border-radius: 10px;
            padding: 14px 12px 12px;
            display: flex;
            flex-direction: column;
            align-items: center;
            gap: 5px;
            position: relative;
            transition: border-color .2s, box-shadow .2s;
        }

        .product-card.has-qty {
            border-color: #00CE86;
            box-shadow: 0 0 0 1px rgba(0, 206, 134, .2);
            background: rgba(0, 206, 134, .03);
        }

        .product-img {
            width: 52px;
            height: 52px;
            background: #2a2a2a;
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            margin-bottom: 2px;
            font-size: .72rem;
            color: #555;
        }

        .product-img svg {
            fill: #444;
            width: 26px;
            height: 26px;
        }

        .disc-badge {
            position: absolute;
            top: 8px;
            right: 8px;
            background: rgba(0, 206, 134, .15);
            border: 1px solid rgba(0, 206, 134, .3);
            color: #00CE86;
            font-size: .65rem;
            font-weight: 700;
            padding: 2px 6px;
            border-radius: 20px;
        }

        .product-name {
            font-size: .85rem;
            font-weight: 600;
            color: #ddd;
            text-align: center;
            line-height: 1.2;
        }

        .product-qlbl {
            font-size: .73rem;
            color: #666;
        }

        .product-price {
            font-size: .95rem;
            font-weight: 700;
            color: #fff;
        }

        .product-price.discounted {
            color: #00CE86;
        }

        .product-price-orig {
            font-size: .74rem;
            color: #555;
            text-decoration: line-through;
        }

        /* ── STEPPER ─────────────────────────────────────── */
        .stepper {
            display: flex;
            align-items: center;
            background: #2a2a2a;
            border: 1px solid #3a3a3a;
            border-radius: 7px;
            overflow: hidden;
            margin-top: 4px;
        }

        .stepper button {
            width: 30px;
            height: 30px;
            background: none;
            border: none;
            color: #aaa;
            font-size: 1.1rem;
            font-weight: 700;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            transition: background .15s, color .15s;
            flex-shrink: 0;
        }

        .stepper button:hover {
            background: #3a3a3a;
            color: #00CE86;
        }

        .stepper button:active {
            background: #444;
        }

        .stepper .qty-val {
            min-width: 32px;
            text-align: center;
            font-size: .9rem;
            font-weight: 700;
            color: #fff;
            border-left: 1px solid #3a3a3a;
            border-right: 1px solid #3a3a3a;
            padding: 0 4px;
            line-height: 30px;
        }

        /* ── RIGHT COLUMN ────────────────────────────────── */
        .right-col {
            display: flex;
            flex-direction: column;
            gap: 14px;
        }

        /* ── SUMMARY PANEL ───────────────────────────────── */
        .summary-panel {
            background: #262626;
            border: 1px solid #333;
            border-radius: 10px;
            overflow: hidden;
        }

        .summary-header {
            padding: 13px 16px;
            border-bottom: 1px solid #333;
        }

        .summary-title {
            font-size: .9rem;
            font-weight: 700;
            color: #e8e8e8;
        }

        .saldo-row {
            padding: 10px 16px;
            border-bottom: 1px solid #2e2e2e;
            display: flex;
            justify-content: space-between;
            font-size: .82rem;
            color: #777;
        }

        .saldo-row strong {
            color: #00CE86;
        }

        .order-items {
            min-height: 44px;
        }

        .order-item {
            padding: 10px 16px;
            border-bottom: 1px solid #2a2a2a;
            display: flex;
            justify-content: space-between;
            align-items: center;
            font-size: .84rem;
        }

        .order-item .iname {
            color: #ccc;
        }

        .order-item .iqty {
            color: #777;
            font-size: .78rem;
            margin-left: 4px;
        }

        .order-item .iprice {
            color: #e0e0e0;
            font-weight: 600;
            flex-shrink: 0;
        }

        .empty-cart {
            padding: 20px 16px;
            text-align: center;
            font-size: .82rem;
            color: #555;
        }

        .total-row {
            padding: 12px 16px;
            border-top: 1px solid #333;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .total-label {
            font-size: .78rem;
            color: #888;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: .5px;
        }

        .total-value {
            font-size: 1.1rem;
            font-weight: 700;
            color: #00CE86;
        }

        .saldo-warn {
            padding: 8px 16px;
            font-size: .78rem;
            color: #f5a623;
            background: rgba(245, 166, 35, .08);
            border-top: 1px solid rgba(245, 166, 35, .2);
            display: none;
        }

        .action-btns {
            padding: 12px 16px;
            display: flex;
            flex-direction: column;
            gap: 8px;
        }

        .btn-confirmar {
            width: 100%;
            padding: 11px;
            background: #00CE86;
            color: #111;
            border: none;
            border-radius: 7px;
            font-size: .92rem;
            font-weight: 700;
            cursor: pointer;
            transition: background .2s, transform .1s;
        }

        .btn-confirmar:hover {
            background: #00b876;
        }

        .btn-confirmar:active {
            transform: scale(.98);
        }

        .btn-confirmar:disabled {
            background: #2a4a3a;
            color: #555;
            cursor: not-allowed;
        }

        .btn-cancelar-lnk {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 5px;
            color: #777;
            text-decoration: none;
            font-size: .84rem;
            padding: 6px;
            border-radius: 6px;
            transition: color .2s;
        }

        .btn-cancelar-lnk:hover {
            color: #e05555;
        }

        .btn-cancelar-lnk svg {
            fill: currentColor;
            width: 13px;
            height: 13px;
        }

        /* ── PROMOS PANEL ────────────────────────────────── */
        .promos-panel {
            background: #262626;
            border: 1px solid #2e2e2e;
            border-radius: 10px;
            overflow: hidden;
        }

        .promos-header {
            padding: 11px 16px;
            border-bottom: 1px solid #2e2e2e;
        }

        .promos-title {
            font-size: .82rem;
            font-weight: 700;
            color: #aaa;
            display: flex;
            align-items: center;
            gap: 6px;
        }

        .promos-title svg {
            fill: #00CE86;
            width: 14px;
            height: 14px;
        }

        .promo-list {
            list-style: none;
        }

        .promo-item {
            padding: 9px 16px;
            border-bottom: 1px solid #272727;
            display: flex;
            justify-content: space-between;
            align-items: center;
            font-size: .82rem;
        }

        .promo-item:last-child {
            border-bottom: none;
        }

        .promo-item .pname {
            color: #bbb;
        }

        .promo-item .pdesc {
            background: rgba(0, 206, 134, .12);
            color: #00CE86;
            border: 1px solid rgba(0, 206, 134, .25);
            font-size: .7rem;
            font-weight: 700;
            padding: 2px 8px;
            border-radius: 20px;
        }

        /* ── RESPONSIVE ──────────────────────────────────── */
        @media (max-width: 750px) {
            .editor-grid {
                grid-template-columns: 1fr;
            }

            .right-col {
                flex-direction: row;
                flex-wrap: wrap;
            }

            .summary-panel,
            .promos-panel {
                flex: 1;
                min-width: 240px;
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

            .product-grid {
                grid-template-columns: repeat(2, 1fr);
                max-height: none;
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

        <!-- ALERTS -->
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

        <!-- EDITOR GRID -->
        <div class="editor-grid">

            <!-- LEFT: PRODUCT GRID -->
            <div class="panel">
                <div class="panel-header">
                    <svg class="panel-icon" viewBox="0 0 24 24">
                        <path d="M7 18c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm10 0c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zM7.17 14l.03-.12.9-1.88H17c.75 0 1.41-.41 1.75-1.03l3.86-7.01A1 1 0 0 0 21.75 2H5.21l-.94-2H1v2h2l3.6 7.59L5.25 11C4.52 11.37 4 12.13 4 13c0 1.1.9 2 2 2h12v-2H7.42c-.13 0-.25-.11-.25-.25z"/>
                    </svg>
                    <span class="panel-title">Escolher produtos</span>
                </div>

                <div class="product-grid">
                    <%
                        for (Object[] p : catalogue) {
                            String pid    = (String)  p[0];
                            String pname  = (String)  p[1];
                            String pqlbl  = (String)  p[2];
                            int price     = (Integer) p[3];
                            int disc      = (Integer) p[4];
                            int curQty    = (Integer) p[5];
                            int origPrice = (Integer) p[6];

                            String priceStr = String.format("%d,%02d €", price / 100, price % 100);
                            String origStr  = String.format("%d,%02d €", origPrice / 100, origPrice % 100);
                            String fullName = pname + (!pqlbl.isEmpty() ? " " + pqlbl : "");
                    %>
                    <div class="product-card <%= curQty > 0 ? "has-qty" : "" %>" id="card-<%= pid %>">
                        <% if (disc > 0) { %><span class="disc-badge">-<%= disc %>%</span><% } %>
                        <div class="product-img">
                            <svg viewBox="0 0 24 24">
                                <path d="M18.06 22.99h1.66c.84 0 1.53-.64 1.63-1.46L23 5.05h-5V1h-1.97v4.05h-4.97l.3 2.34c1.71.47 3.31 1.32 4.27 2.26 1.44 1.42 2.43 2.89 2.43 5.29v8.05zM1 21.99V21h15.03v.99c0 .55-.45 1-1.01 1H2.01c-.56 0-1.01-.45-1.01-1zm15.03-7c0-3.87-3.13-7-7-7S2 11.12 2 14.99v2h14.03v-2z"/>
                            </svg>
                        </div>
                        <div class="product-name"><%= pname %></div>
                        <% if (!pqlbl.isEmpty()) { %>
                        <div class="product-qlbl"><%= pqlbl %></div>
                        <% } %>
                        <div class="product-price <%= disc > 0 ? "discounted" : "" %>"><%= priceStr %></div>
                        <% if (disc > 0) { %>
                        <div class="product-price-orig"><%= origStr %></div>
                        <% } %>
                        <div class="stepper">
                            <button type="button" onclick="changeQty('<%= pid %>',-1,<%= price %>,'<%= fullName %>')">&#8722;</button>
                            <span class="qty-val" id="qty-<%= pid %>"><%= curQty %></span>
                            <button type="button" onclick="changeQty('<%= pid %>',1,<%= price %>,'<%= fullName %>')">&#43;</button>
                        </div>
                    </div>
                    <% } %>
                </div>
            </div>

            <!-- RIGHT COLUMN -->
            <div class="right-col">

                <!-- Summary panel -->
                <div class="summary-panel">
                    <div class="summary-header">
                        <div class="summary-title">Resumo</div>
                    </div>

                    <div class="saldo-row">
                        <span>Saldo do cliente</span>
                        <strong><%= saldoCliente %> &euro;</strong>
                    </div>

                    <div class="order-items" id="orderItems"></div>

                    <div class="total-row">
                        <span class="total-label">Total</span>
                        <span class="total-value" id="totalValue">0,00 &euro;</span>
                    </div>

                    <div class="saldo-warn" id="saldoWarn">&#9888; Saldo insuficiente.</div>

                    <% if (!isNova) { %>
                    <div style="padding:10px 16px;border-bottom:1px solid #2e2e2e;">
                        <div style="font-size:.76rem;color:#777;margin-bottom:5px;">Alterar estado</div>
                        <select id="estadoSelect" class="estado-select" style="width:100%;background:#1e1e1e;border:1px solid #3a3a3a;border-radius:7px;color:#ddd;font-size:.85rem;padding:8px 10px;outline:none;">
                            <option value="pendente"    <%= "pendente".equals(orderStatus)    ? "selected" : "" %>>Pendente</option>
                            <option value="processando" <%= "processando".equals(orderStatus) ? "selected" : "" %>>Processando</option>
                            <option value="pronto"      <%= "pronto".equals(orderStatus)      ? "selected" : "" %>>Pronto</option>
                            <option value="cancelado"   <%= "cancelado".equals(orderStatus)   ? "selected" : "" %>>Cancelado</option>
                        </select>
                    </div>
                    <% } %>

                    <div class="action-btns">
                        <form id="orderForm" action="criarEditarEncomendaAdmin.jsp" method="post"
                              onsubmit="return prepareSubmit()">
                            <% if (orderId != null) { %>
                            <input type="hidden" name="orderId" value="<%= orderId %>"/>
                            <% } %>
                            <input type="hidden" name="clienteId" value="<%= clientUserId %>"/>
                            <input type="hidden" id="estadoHidden" name="estado" value="<%= orderStatus %>"/>
                            <div id="hiddenInputs"></div>
                            <button type="submit" class="btn-confirmar" id="btnConfirmar">
                                Confirmar encomenda
                            </button>
                        </form>

                        <a href="encomendasAdmin.jsp" class="btn-cancelar-lnk">
                            <svg viewBox="0 0 24 24">
                                <path d="M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z"/>
                            </svg>
                            Cancelar
                        </a>
                    </div>
                </div>

                <!-- Active promotions -->
                <div class="promos-panel">
                    <div class="promos-header">
                        <div class="promos-title">
                            <svg viewBox="0 0 24 24">
                                <path d="M21.41 11.58l-9-9A2 2 0 0 0 11 2H4a2 2 0 0 0-2 2v7c0 .53.21 1.04.59 1.42l9 9A2 2 0 0 0 13 22a2 2 0 0 0 1.41-.59l7-7A2 2 0 0 0 22 13a2 2 0 0 0-.59-1.42zM5.5 7C4.67 7 4 6.33 4 5.5S4.67 4 5.5 4 7 4.67 7 5.5 6.33 7 5.5 7z"/>
                            </svg>
                            Promoções ativas
                        </div>
                    </div>
                    <ul class="promo-list">
                        <%
                            for (Object[] p : catalogue) {
                                int d = (Integer) p[4];
                                if (d > 0) {
                                    String pn = (String) p[1];
                                    String ql = (String) p[2];
                        %>
                        <li class="promo-item">
                            <span class="pname"><%= pn %><%= !ql.isEmpty() ? " " + ql : "" %></span>
                            <span class="pdesc">-<%= d %>%</span>
                        </li>
                        <%
                                }
                            }
                        %>
                    </ul>
                </div>

            </div>
        </div>
    </main>
</div>

<script>
    const saldo = <%= saldoCliente.replace(",", ".") %>;
    const cart = {};

    <% for (Object[] p : catalogue) {
           String pid = (String)  p[0];
           String pn  = (String)  p[1];
           String ql  = (String)  p[2];
           int price  = (Integer) p[3];
           int curQty = (Integer) p[5];
           if (curQty > 0) { %>
    cart['<%= pid %>'] = {name: '<%= pn + (!ql.isEmpty() ? " "+ql : "") %>', price: <%= price %>, qty: <%= curQty %>};
    <% }} %>

    function fmt(cents) {
        return (cents / 100).toFixed(2).replace('.', ',') + ' €';
    }

    function changeQty(pid, delta, price, name) {
        const el   = document.getElementById('qty-' + pid);
        const card = document.getElementById('card-' + pid);
        let qty = parseInt(el.textContent) + delta;
        if (qty < 0) qty = 0;
        el.textContent = qty;
        if (qty > 0) {
            cart[pid] = {name, price, qty};
            card.classList.add('has-qty');
        } else {
            delete cart[pid];
            card.classList.remove('has-qty');
        }
        render();
    }

    function render() {
        const items = Object.entries(cart);
        const box   = document.getElementById('orderItems');

        if (!items.length) {
            box.innerHTML = '<div class="empty-cart">Nenhum produto selecionado.</div>';
            document.getElementById('totalValue').textContent = '0,00 €';
            document.getElementById('btnConfirmar').disabled = true;
            document.getElementById('saldoWarn').style.display = 'none';
            return;
        }

        let total = 0, html = '';
        items.forEach(([, item]) => {
            const sub = item.price * item.qty;
            total += sub;
            html += `<div class="order-item">
                <span><span class="iname">${item.name}</span><span class="iqty">× ${item.qty}</span></span>
                <span class="iprice">${fmt(sub)}</span>
            </div>`;
        });
        box.innerHTML = html;
        document.getElementById('totalValue').textContent = fmt(total);

        const insuf = total > Math.round(saldo * 100);
        document.getElementById('saldoWarn').style.display = insuf ? 'block' : 'none';
        document.getElementById('btnConfirmar').disabled = insuf;
    }

    const estadoSelectEl = document.getElementById('estadoSelect');
    if (estadoSelectEl) {
        estadoSelectEl.addEventListener('change', function () {
            document.getElementById('estadoHidden').value = this.value;
        });
    }

    function prepareSubmit() {
        const hi      = document.getElementById('hiddenInputs');
        const entries = Object.entries(cart);
        if (!entries.length) return false;
        hi.innerHTML  = '';
        entries.forEach(([pid, item]) => {
            hi.innerHTML += `<input type="hidden" name="produto_${pid}" value="${item.qty}"/>`;
        });
        return true;
    }

    render();
</script>

</body>
</html>

