<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*" %>
<%
    HttpSession sess = request.getSession(false);
    sess.invalidate();
    response.sendRedirect("index.jsp");
%>