<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.sql.*" %>
<%@ include file="../basedados/basedados.h" %>
<%
    // Verificar sessao
    HttpSession sess = request.getSession(false);
    if (sess == null || sess.getAttribute("userId") == null) {
        response.sendRedirect("login.jsp");
        return;
    }

    String role = (String) sess.getAttribute("userRole");
    if (!role.equals("cliente")) {
        response.sendRedirect("login.jsp");
        return;
    }

    int userId = (Integer) sess.getAttribute("userId");

    // Ler id da encomenda no url
    int encomendaId = Integer.parseInt(request.getParameter("id"));

    Connection conn = null;
    PreparedStatement ps = null;
    ResultSet rs = null;

    try {
        conn = getConnection();

        // Verificar se a encomenda pertence ao utilizador
        String sqlCheck = "SELECT id_encomenda, estado " +
                "FROM encomenda " +
                "WHERE id_encomenda = ? AND id_utilizador = ?";
        ps = conn.prepareStatement(sqlCheck);
        ps.setInt(1, encomendaId);
        ps.setInt(2, userId);
        rs = ps.executeQuery();

        if (!rs.next()) {
            // Encomenda não encontrada ou não pertence ao utilizador
            sess.setAttribute("error", "Encomenda #" + encomendaId + " não encontrada.");
            response.sendRedirect("encomendas.jsp");
            return;
        }

        String estadoAtual = rs.getString("estado");
        rs.close();
        ps.close();
        rs = null;
        ps = null;

        //  Verificar se o estado permite cancelamento
        boolean podeCancelar = "pendente".equalsIgnoreCase(estadoAtual) || "processando".equalsIgnoreCase(estadoAtual);

        if (!podeCancelar) {
            sess.setAttribute("error",
                    "Não é possível cancelar a encomenda #" + encomendaId);
            response.sendRedirect("encomendas.jsp");
            return;
        }

        // Atualizar estado para 'cancelado'
        String sqlUpdate = "UPDATE encomenda SET estado = 'cancelado' " +
                "WHERE id_encomenda = ? AND id_utilizador = ?";
        ps = conn.prepareStatement(sqlUpdate);
        ps.setInt(1, encomendaId);
        ps.setInt(2, userId);
        int rows = ps.executeUpdate();
        ps.close();
        ps = null;

        // Devolver saldo ao cliente
        String sqlSaldoCheck = "SELECT total FROM encomenda WHERE id_encomenda = ?";
        ps = conn.prepareStatement(sqlSaldoCheck);
        ps.setInt(1, encomendaId);
        rs = ps.executeQuery();

        if (rs.next()) {
            double totalPago = rs.getDouble("total");
            rs.close();
            ps.close();
            rs = null;
            ps = null;

            String sqlDevolucao = "UPDATE utilizadores " +
                    "SET saldo = saldo + ? " +
                    "WHERE id_utilizador = ?";
            ps = conn.prepareStatement(sqlDevolucao);
            ps.setDouble(1, totalPago);
            ps.setInt(2, userId);
            ps.executeUpdate();
            ps.close();
            ps = null;

            // Registar movimento na auditoria
            String sqlAuditoria = "INSERT INTO auditoria_movimento " +
                    "(id_carteira_origem, id_carteira_destino, tipo, valor, descricao, data_operacao) " +
                    "VALUES (?, 1, 'devolucao', ?, ?, NOW())";
            ps = conn.prepareStatement(sqlAuditoria);
            ps.setInt(1, userId);
            ps.setDouble(2, totalPago);
            ps.setString(3, "Devolução — encomenda #" + encomendaId + " cancelada");
            ps.executeUpdate();
            ps.close();
            ps = null;
        }

        // Redirecionar com mensagem
        sess.setAttribute("success",
                "Encomenda #" + encomendaId + " cancelada com sucesso.");
        response.sendRedirect("encomendas.jsp");

    } catch (Exception e) {
        sess.setAttribute("error", "Erro ao cancelar: " + e.getMessage());
        response.sendRedirect("encomendas.jsp");

    } finally {
        try {
            if (rs != null) rs.close();
        } catch (Exception ignored) {
        }
        try {
            if (ps != null) ps.close();
        } catch (Exception ignored) {
        }
        try {
            if (conn != null) conn.close();
        } catch (Exception ignored) {
        }
    }
%>