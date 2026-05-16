<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*" %>
<%
    String errorMsg = (String) request.getAttribute("error");
    String emailVal = request.getParameter("email") != null ? request.getParameter("email") : "";
%>
<!DOCTYPE html>
<html lang="pt">
<head>
    <meta charset="UTF-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <title>FelixUberShop – Entrar</title>
    <style>
        *, *::before, *::after {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            background-color: #171717;
            color: #e0e0e0;
            font-family: 'Segoe UI', Arial, sans-serif;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
        }

        nav {
            background-color: #222222;
            padding: 14px 32px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            border-bottom: 1px solid #2e2e2e;
        }

        .nav-brand {
            font-size: 1.35rem;
            font-weight: 700;
            color: #00CE86;
            letter-spacing: 0.5px;
            text-decoration: none;
        }

        .nav-links {
            display: flex;
            gap: 24px;
        }

        .nav-links a {
            color: #aaa;
            text-decoration: none;
            font-size: 0.9rem;
            transition: color 0.2s;
        }

        .nav-links a:hover {
            color: #00CE86;
        }

        main {
            flex: 1;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 48px 16px;
        }

        .card {
            background-color: #2b2b2b;
            border: 1px solid #383838;
            border-radius: 14px;
            padding: 44px 40px 36px;
            width: 100%;
            max-width: 420px;
            box-shadow: 0 8px 40px rgba(0, 0, 0, 0.55);
        }

        .avatar-wrap {
            display: flex;
            justify-content: center;
            margin-bottom: 24px;
        }

        .avatar {
            width: 72px;
            height: 72px;
            background-color: #383838;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .avatar svg {
            width: 40px;
            height: 40px;
            fill: #00CE86;
        }

        .card-title {
            text-align: center;
            font-size: 1.5rem;
            font-weight: 700;
            color: #ffffff;
            margin-bottom: 6px;
        }

        .card-subtitle {
            text-align: center;
            font-size: 0.85rem;
            color: #888;
            margin-bottom: 32px;
        }

        .form-group {
            margin-bottom: 18px;
        }

        label {
            display: block;
            font-size: 0.82rem;
            color: #aaa;
            margin-bottom: 7px;
            letter-spacing: 0.3px;
        }

        .input-wrap {
            position: relative;
        }

        .input-wrap .icon {
            position: absolute;
            left: 14px;
            top: 50%;
            transform: translateY(-50%);
            display: flex;
            align-items: center;
            color: #666;
        }

        .input-wrap .icon svg {
            width: 17px;
            height: 17px;
            fill: currentColor;
        }

        input[type="email"],
        input[type="password"] {
            width: 100%;
            background-color: #1e1e1e;
            border: 1px solid #3e3e3e;
            border-radius: 8px;
            color: #e0e0e0;
            font-size: 0.92rem;
            padding: 11px 14px 11px 42px;
            outline: none;
            transition: border-color 0.2s, box-shadow 0.2s;
        }

        input[type="email"]::placeholder,
        input[type="password"]::placeholder {
            color: #555;
        }

        input[type="email"]:focus,
        input[type="password"]:focus {
            border-color: #00CE86;
            box-shadow: 0 0 0 3px rgba(0, 206, 134, 0.15);
        }

        .toggle-pw {
            position: absolute;
            right: 13px;
            top: 50%;
            transform: translateY(-50%);
            background: none;
            border: none;
            cursor: pointer;
            color: #666;
            display: flex;
            align-items: center;
            padding: 0;
            transition: color 0.2s;
        }

        .toggle-pw:hover {
            color: #00CE86;
        }

        .toggle-pw svg {
            width: 17px;
            height: 17px;
            fill: currentColor;
        }

        .forgot-row {
            display: flex;
            justify-content: flex-end;
            margin-top: 6px;
        }

        .forgot-row a {
            font-size: 0.78rem;
            color: #666;
            text-decoration: none;
            transition: color 0.2s;
        }

        .forgot-row a:hover {
            color: #00CE86;
        }

        .error-msg {
            background-color: rgba(220, 60, 60, 0.15);
            border: 1px solid rgba(220, 60, 60, 0.35);
            color: #f08080;
            border-radius: 8px;
            padding: 10px 14px;
            font-size: 0.84rem;
            margin-bottom: 18px;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .btn-submit {
            width: 100%;
            padding: 13px;
            background-color: #00CE86;
            color: #111;
            border: none;
            border-radius: 8px;
            font-size: 1rem;
            font-weight: 700;
            cursor: pointer;
            letter-spacing: 0.4px;
            margin-top: 10px;
            transition: background-color 0.2s, transform 0.1s;
        }

        .btn-submit:hover {
            background-color: #00b876;
        }

        .btn-submit:active {
            transform: scale(0.98);
        }

        .divider {
            display: flex;
            align-items: center;
            gap: 12px;
            margin: 22px 0 20px;
            color: #444;
            font-size: 0.75rem;
        }

        .divider::before,
        .divider::after {
            content: '';
            flex: 1;
            height: 1px;
            background: #383838;
        }

        .register-row {
            text-align: center;
            font-size: 0.85rem;
            color: #777;
        }

        .register-row a {
            color: #00CE86;
            text-decoration: none;
            font-weight: 600;
            transition: color 0.2s;
        }

        .register-row a:hover {
            color: #00b876;
            text-decoration: underline;
        }

        footer {
            text-align: center;
            padding: 16px;
            font-size: 0.75rem;
            color: #3d3d3d;
        }
    </style>
</head>
<body>

<!-- NAV -->
<nav>
    <a href="index.jsp" class="nav-brand">FelixUberShop</a>
    <div class="nav-links">
        <a href="index.jsp">Início</a>
        <a href="register.jsp">Registar</a>
    </div>
</nav>

<!-- MAIN -->
<main>
    <div class="card">

        <!-- Avatar icon -->
        <div class="avatar-wrap">
            <div class="avatar">
                <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                    <path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/>
                </svg>
            </div>
        </div>

        <h1 class="card-title">Bem-vindo de volta</h1>
        <p class="card-subtitle">Entre na sua conta FelixUberShop</p>

        <!-- Error message -->
        <% if (errorMsg != null && !errorMsg.isEmpty()) { %>
        <div class="error-msg">
            <svg viewBox="0 0 24 24" width="16" height="16" fill="#f08080">
                <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/>
            </svg>
            <%= errorMsg %>
        </div>
        <% } %>

        <!-- Login form -->
        <form action="LoginServlet" method="post" autocomplete="off">

            <!-- Email -->
            <div class="form-group">
                <label for="email">Email</label>
                <div class="input-wrap">
                        <span class="icon">
                            <svg viewBox="0 0 24 24"><path
                                    d="M20 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 4-8 5-8-5V6l8 5 8-5v2z"/></svg>
                        </span>
                    <input
                            type="email"
                            id="email"
                            name="email"
                            placeholder="felixubershop@felixubershop.com"
                            value="<%= emailVal %>"
                            required
                    />
                </div>
            </div>

            <!-- Password -->
            <div class="form-group">
                <label for="password">Palavra-passe</label>
                <div class="input-wrap">
                        <span class="icon">
                            <svg viewBox="0 0 24 24"><path
                                    d="M18 8h-1V6A5 5 0 0 0 7 6v2H6a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V10a2 2 0 0 0-2-2zm-6 9a2 2 0 1 1 0-4 2 2 0 0 1 0 4zm3.1-9H8.9V6a3.1 3.1 0 0 1 6.2 0v2z"/></svg>
                        </span>
                    <input
                            type="password"
                            id="password"
                            name="password"
                            placeholder="••••••••"
                            required
                    />
                    <button type="button" class="toggle-pw" onclick="togglePw()" title="Mostrar/ocultar palavra-passe">
                        <svg id="eye-icon" viewBox="0 0 24 24">
                            <path d="M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5C21.27 7.61 17 4.5 12 4.5zm0 12.5a5 5 0 1 1 0-10 5 5 0 0 1 0 10zm0-8a3 3 0 1 0 0 6 3 3 0 0 0 0-6z"/>
                        </svg>
                    </button>
                </div>
                <div class="forgot-row">
                    <a href="ForgotPasswordServlet">Esqueceu a palavra-passe?</a>
                </div>
            </div>

            <button type="submit" class="btn-submit">Entrar</button>
        </form>

        <div class="divider">ou</div>

        <p class="register-row">
            Não tem conta? <a href="register.jsp">Registar aqui</a>
        </p>

    </div>
</main>

<footer>
    &copy; <%= java.time.Year.now().getValue() %> FelixUberShop. Todos os direitos reservados.
</footer>

<script>
    function togglePw() {
        const pwInput = document.getElementById('password');
        const icon = document.getElementById('eye-icon');
        if (pwInput.type === 'password') {
            pwInput.type = 'text';

            icon.innerHTML = '<path d="M12 7c2.76 0 5 2.24 5 5 0 .65-.13 1.26-.36 1.83l2.92 2.92c1.51-1.26 2.7-2.89 3.43-4.75C21.27 7.61 17 4.5 12 4.5c-1.29 0-2.53.25-3.67.7l2.16 2.16C11 7.13 11.48 7 12 7zm-9.71-1.14L4.47 8.04C2.75 9.33 1.4 11.1.72 13.15 2.46 17.54 6.72 20.5 12 20.5c1.51 0 2.97-.3 4.29-.83l.42.42L19.73 23 21 21.73 3.27 4 2.29 5.86zM7 12c0-2.76 2.24-5 5-5 .77 0 1.5.18 2.14.49L12 9.63C11.8 9.55 11.41 9.5 11 9.5 9.34 9.5 8 10.84 8 12.5c0 .41.05.8.13 1.18L6.15 11.7C6.05 11.49 7 11.27 7 12z"/>';
        } else {
            pwInput.type = 'password';
            icon.innerHTML = '<path d="M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5C21.27 7.61 17 4.5 12 4.5zm0 12.5a5 5 0 1 1 0-10 5 5 0 0 1 0 10zm0-8a3 3 0 1 0 0 6 3 3 0 0 0 0-6z"/>';
        }
    }
</script>

</body>
</html>
