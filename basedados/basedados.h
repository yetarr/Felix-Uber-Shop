<%@ page import="java.sql.Connection" %>
<%@ page import="java.sql.DriverManager" %>
<%@ page import="java.sql.PreparedStatement" %>
<%@ page import="java.sql.ResultSet" %>
<%@ page import="java.sql.SQLException" %>
<%!
    private static final String DB_HOST = "localhost";
    private static final String DB_PORT = "3306";
    private static final String DB_NAME = "felixubershop";
    private static final String DB_USER = "root";
    private static final String DB_PASS = "root";

    private static final String DB_URL =
        "jdbc:mysql://" + DB_HOST + ":" + DB_PORT + "/" + DB_NAME;

    private static final String DB_DRIVER = "com.mysql.cj.jdbc.Driver";

    public Connection getConnection() throws Exception {
        Class.forName(DB_DRIVER);
        return DriverManager.getConnection(DB_URL, DB_USER, "");
    }

    public void closeConnection(Connection con) {
        if (con != null) {
            try { con.close(); } catch (SQLException ignored) {}
        }
    }

    public void closeStatement(PreparedStatement ps) {
        if (ps != null) {
            try { ps.close(); } catch (SQLException ignored) {}
        }
    }

    public void closeResultSet(ResultSet rs) {
        if (rs != null) {
            try { rs.close(); } catch (SQLException ignored) {}
        }
    }

    public void closeAll(ResultSet rs, PreparedStatement ps, Connection con) {
        closeResultSet(rs);
        closeStatement(ps);
        closeConnection(con);
    }
%>
