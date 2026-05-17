<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*" %>
<%
    // Obter a sessao atual
    HttpSession sess = request.getSession(false);

    // Terminar a sessao do utilizador
    if (sess != null) {
        sess.invalidate();
    }

    // Redirecionar para a pagina inicial
    response.sendRedirect("index.jsp");
%>