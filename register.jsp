<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*" %>
<%@ page import="java.security.MessageDigest, java.nio.charset.StandardCharsets" %>
<%@ include file="basedados/basedados.h"%>
<%!
    // Hashing da password
    private String hashPassword(String plain) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] hash = md.digest(plain.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : hash) sb.append(String.format("%02x", b));
            return sb.toString();
        } catch (Exception e) {
            throw new RuntimeException("Erro ao encriptar password", e);
        }
    }
%>
<%
    String errorMsg = null;
    String successMsg = null;

    String nomeVal = "";
    String emailVal = "";
    String telefoneVal = "";

    if ("POST".equalsIgnoreCase(request.getMethod())) {
        nomeVal = request.getParameter("nome") != null ? request.getParameter("nome") : "";
        emailVal = request.getParameter("email") != null ? request.getParameter("email") : "";
        telefoneVal = request.getParameter("telefone") != null ? request.getParameter("telefone") : "";
        String password = request.getParameter("password");
        String confirm  = request.getParameter("confirmPassword");

        // Validacao dos campos
        if (nomeVal.isBlank() || emailVal.isBlank() || password == null || password.isBlank()) {
            errorMsg = "Preencha todos os campos obrigatórios.";

        } else if (!password.equals(confirm)) {
            errorMsg = "As passwords não coincidem.";

        } else if (password.length() < 6) {
            errorMsg = "A password deve ter mínimo 6 caracteres.";

        } else {
            try {
                Connection conn = getConnection();

                // Verificar por emails duplicados
                String checkSql = "SELECT id_utilizador FROM utilizadores WHERE email = ?";
                PreparedStatement check = conn.prepareStatement(checkSql);
                check.setString(1, emailVal);
                if (check.executeQuery().next()) {
                    errorMsg = "Este email já está registado.";
                } else {
                    // Inserir dados a base de dados
                    String insertSql = "INSERT INTO utilizadores (nome, email, telefone, password_hash, perfil) " +
                            "VALUES (?, ?, ?, ?, 'cliente')";
                    PreparedStatement ps = conn.prepareStatement(insertSql);
                    ps.setString(1, nomeVal);
                    ps.setString(2, emailVal);
                    ps.setString(3, telefoneVal);
                    ps.setString(4, hashPassword(password));
                    ps.executeUpdate();
                    ps.close();

                    // Redirecionar para o login
                    request.getSession().setAttribute("success", "Conta criada! Pode iniciar sessão.");
                    conn.close();
                    response.sendRedirect("login.jsp");
                    return;
                }

                check.close(); conn.close();
            } catch (Exception e) {
                errorMsg = "Erro ao criar conta: " + e.getMessage();
            }
        }
    }
%>
<!DOCTYPE html>
<html lang="pt">
<head>
    <meta charset="UTF-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <title>FelixUberShop – Criar conta</title>
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
            padding: 40px 16px;
        }

        .card {
            background-color: #2b2b2b;
            border: 1px solid #383838;
            border-radius: 14px;
            padding: 38px 40px 32px;
            width: 100%;
            max-width: 460px;
            box-shadow: 0 8px 40px rgba(0, 0, 0, 0.55);
        }

        .card-header {
            display: flex;
            flex-direction: column;
            align-items: center;
            margin-bottom: 28px;
        }

        .avatar {
            width: 64px;
            height: 64px;
            background-color: #383838;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            margin-bottom: 14px;
        }

        .avatar svg {
            width: 34px;
            height: 34px;
            fill: #00CE86;
        }

        .card-title {
            font-size: 1.4rem;
            font-weight: 700;
            color: #ffffff;
            margin-bottom: 4px;
        }

        .card-subtitle {
            font-size: 0.83rem;
            color: #777;
        }

        .form-group {
            margin-bottom: 15px;
        }

        label {
            display: block;
            font-size: 0.81rem;
            color: #aaa;
            margin-bottom: 6px;
            letter-spacing: 0.3px;
        }

        label .required {
            color: #00CE86;
            margin-left: 2px;
        }

        .input-wrap {
            position: relative;
        }

        .input-wrap .icon {
            position: absolute;
            left: 13px;
            top: 50%;
            transform: translateY(-50%);
            display: flex;
            align-items: center;
            color: #666;
        }

        .input-wrap .icon svg {
            width: 16px;
            height: 16px;
            fill: currentColor;
        }

        input[type="text"],
        input[type="email"],
        input[type="tel"],
        input[type="password"] {
            width: 100%;
            background-color: #1e1e1e;
            border: 1px solid #3e3e3e;
            border-radius: 8px;
            color: #e0e0e0;
            font-size: 0.91rem;
            padding: 10px 13px 10px 40px;
            outline: none;
            transition: border-color 0.2s, box-shadow 0.2s;
        }

        input::placeholder {
            color: #505050;
        }

        input:focus {
            border-color: #00CE86;
            box-shadow: 0 0 0 3px rgba(0, 206, 134, 0.15);
        }

        input.error-field {
            border-color: #c0392b;
        }

        .hint {
            font-size: 0.74rem;
            color: #666;
            margin-top: 5px;
        }

        .toggle-pw {
            position: absolute;
            right: 12px;
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
            width: 16px;
            height: 16px;
            fill: currentColor;
        }

        .alert {
            border-radius: 8px;
            padding: 10px 14px;
            font-size: 0.84rem;
            margin-bottom: 18px;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .alert-error {
            background-color: rgba(220, 60, 60, 0.15);
            border: 1px solid rgba(220, 60, 60, 0.35);
            color: #f08080;
        }

        .alert-success {
            background-color: rgba(0, 206, 134, 0.12);
            border: 1px solid rgba(0, 206, 134, 0.35);
            color: #00CE86;
        }

        .row-2col {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 12px;
        }

        .btn-submit {
            width: 100%;
            padding: 12px;
            background-color: #00CE86;
            color: #111;
            border: none;
            border-radius: 8px;
            font-size: 0.97rem;
            font-weight: 700;
            cursor: pointer;
            letter-spacing: 0.4px;
            margin-top: 8px;
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
            margin: 20px 0 18px;
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

        .login-row {
            text-align: center;
            font-size: 0.85rem;
            color: #777;
        }

        .login-row a {
            color: #00CE86;
            text-decoration: none;
            font-weight: 600;
            transition: color 0.2s;
        }

        .login-row a:hover {
            color: #00b876;
            text-decoration: underline;
        }

        footer {
            text-align: center;
            padding: 16px;
            font-size: 0.75rem;
            color: #3d3d3d;
        }

        @media (max-width: 480px) {
            .card {
                padding: 28px 18px 24px;
            }

            .row-2col {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>

<nav>
    <a href="index.jsp" class="nav-brand">FelixUberShop</a>
    <div class="nav-links">
        <a href="index.jsp">Início</a>
        <a href="login.jsp">Entrar</a>
    </div>
</nav>

<main>
    <div class="card">

        <div class="card-header">
            <div class="avatar">
                <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                    <path d="M15 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm-9-2V7H4v3H1v2h3v3h2v-3h3v-2H6zm9 4c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/>
                </svg>
            </div>
            <h1 class="card-title">Criar conta</h1>
            <p class="card-subtitle">Junte-se à FelixUberShop hoje</p>
        </div>

        <% if (errorMsg != null && !errorMsg.isEmpty()) { %>
        <div class="alert alert-error">
            <svg viewBox="0 0 24 24" width="16" height="16" fill="#f08080">
                <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/>
            </svg>
            <%= errorMsg %>
        </div>
        <% } %>

        <% if (successMsg != null && !successMsg.isEmpty()) { %>
        <div class="alert alert-success">
            <svg viewBox="0 0 24 24" width="16" height="16" fill="#00CE86">
                <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 14l-4-4 1.41-1.41L10 13.17l6.59-6.59L18 8l-8 8z"/>
            </svg>
            <%= successMsg %>
        </div>
        <% } %>

        <form action="register.jsp" method="post" autocomplete="off" onsubmit="return validateForm()">

            <div class="form-group">
                <label for="nome">Nome completo <span class="required">*</span></label>
                <div class="input-wrap">
                        <span class="icon">
                            <svg viewBox="0 0 24 24">
                                <path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/>
                            </svg>
                        </span>
                    <input
                            type="text"
                            id="nome"
                            name="nome"
                            placeholder="O seu nome"
                            value="<%= nomeVal %>"
                            required
                    />
                </div>
            </div>

            <div class="form-group">
                <label for="email">Email <span class="required">*</span></label>
                <div class="input-wrap">
                        <span class="icon">
                            <svg viewBox="0 0 24 24">
                                <path d="M20 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 4-8 5-8-5V6l8 5 8-5v2z"/>
                            </svg>
                        </span>
                    <input
                            type="email"
                            id="email"
                            name="email"
                            placeholder="exemplo@email.com"
                            value="<%= emailVal %>"
                            required
                    />
                </div>
            </div>

            <div class="form-group">
                <label for="telefone">Telefone</label>
                <div class="input-wrap">
                        <span class="icon">
                            <svg viewBox="0 0 24 24">
                                <path d="M6.62 10.79a15.05 15.05 0 0 0 6.59 6.59l2.2-2.2c.27-.27.67-.36 1.02-.24 1.12.37 2.33.57 3.57.57.55 0 1 .45 1 1V20c0 .55-.45 1-1 1C10.28 21 3 13.72 3 4.5c0-.55.45-1 1-1H7c.55 0 1 .45 1 1 0 1.25.2 2.45.57 3.57.11.35.03.74-.24 1.02l-2.2 2.2z"/>
                            </svg>
                        </span>
                    <input
                            type="tel"
                            id="telefone"
                            name="telefone"
                            placeholder="0XX XXX XXX"
                            value="<%= telefoneVal %>"
                            pattern="[0-9+\s\-]{7,15}"
                    />
                </div>
            </div>

            <div class="row-2col">

                <div class="form-group">
                    <label for="password">Password <span class="required">*</span></label>
                    <div class="input-wrap">
                            <span class="icon">
                                <svg viewBox="0 0 24 24">
                                    <path d="M18 8h-1V6A5 5 0 0 0 7 6v2H6a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V10a2 2 0 0 0-2-2zm-6 9a2 2 0 1 1 0-4 2 2 0 0 1 0 4zm3.1-9H8.9V6a3.1 3.1 0 0 1 6.2 0v2z"/>
                                </svg>
                            </span>
                        <input
                                type="password"
                                id="password"
                                name="password"
                                placeholder="••••••"
                                minlength="6"
                                required
                        />
                        <button type="button" class="toggle-pw" onclick="togglePw('password','eye1')"
                                title="Mostrar/ocultar">
                            <svg id="eye1" viewBox="0 0 24 24">
                                <path d="M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5C21.27 7.61 17 4.5 12 4.5zm0 12.5a5 5 0 1 1 0-10 5 5 0 0 1 0 10zm0-8a3 3 0 1 0 0 6 3 3 0 0 0 0-6z"/>
                            </svg>
                        </button>
                    </div>
                    <p class="hint">Mínimo 6 caracteres</p>
                </div>

                <div class="form-group">
                    <label for="confirmPassword">Confirmar Password <span class="required">*</span></label>
                    <div class="input-wrap">
                            <span class="icon">
                                <svg viewBox="0 0 24 24">
                                    <path d="M18 8h-1V6A5 5 0 0 0 7 6v2H6a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V10a2 2 0 0 0-2-2zm-6 9a2 2 0 1 1 0-4 2 2 0 0 1 0 4zm3.1-9H8.9V6a3.1 3.1 0 0 1 6.2 0v2z"/>
                                </svg>
                            </span>
                        <input
                                type="password"
                                id="confirmPassword"
                                name="confirmPassword"
                                placeholder="••••••"
                                required
                        />
                        <button type="button" class="toggle-pw" onclick="togglePw('confirmPassword','eye2')"
                                title="Mostrar/ocultar">
                            <svg id="eye2" viewBox="0 0 24 24">
                                <path d="M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5C21.27 7.61 17 4.5 12 4.5zm0 12.5a5 5 0 1 1 0-10 5 5 0 0 1 0 10zm0-8a3 3 0 1 0 0 6 3 3 0 0 0 0-6z"/>
                            </svg>
                        </button>
                    </div>
                    <p class="hint" id="pwMatchHint">&nbsp;</p>
                </div>

            </div>

            <button type="submit" class="btn-submit">Criar conta</button>
        </form>

        <div class="divider">ou</div>

        <p class="login-row">
            Já tem conta? <a href="login.jsp">Entrar aqui</a>
        </p>

    </div>
</main>

<footer>
    &copy; <%= java.time.Year.now().getValue() %> FelixUberShop. Todos os direitos reservados.
</footer>

<script>
    const eyeOpen = '<path d="M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5C21.27 7.61 17 4.5 12 4.5zm0 12.5a5 5 0 1 1 0-10 5 5 0 0 1 0 10zm0-8a3 3 0 1 0 0 6 3 3 0 0 0 0-6z"/>';
    const eyeClosed = '<path d="M12 7c2.76 0 5 2.24 5 5 0 .65-.13 1.26-.36 1.83l2.92 2.92c1.51-1.26 2.7-2.89 3.43-4.75C21.27 7.61 17 4.5 12 4.5c-1.29 0-2.53.25-3.67.7l2.16 2.16C11 7.13 11.48 7 12 7zm-9.71-1.14L4.47 8.04C2.75 9.33 1.4 11.1.72 13.15 2.46 17.54 6.72 20.5 12 20.5c1.51 0 2.97-.3 4.29-.83l.42.42L19.73 23 21 21.73 3.27 4l-.98 1.86zM7 12c0-2.76 2.24-5 5-5 .77 0 1.5.18 2.14.49L12 9.63c-.2-.08-.59-.13-1-.13C9.34 9.5 8 10.84 8 12.5c0 .41.05.8.13 1.18L6.15 11.7C6.05 11.49 7 11.27 7 12z"/>';

    function togglePw(inputId, iconId) {
        const input = document.getElementById(inputId);
        const icon = document.getElementById(iconId);
        if (input.type === 'password') {
            input.type = 'text';
            icon.innerHTML = eyeClosed;
        } else {
            input.type = 'password';
            icon.innerHTML = eyeOpen;
        }
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
        if (pwField.value === confirmField.value) {
            matchHint.textContent = '✓ Passwords coincidem';
            matchHint.style.color = '#00CE86';
            confirmField.classList.remove('error-field');
        } else {
            matchHint.textContent = '✗ Não coincidem';
            matchHint.style.color = '#f08080';
            confirmField.classList.add('error-field');
        }
    }

    pwField.addEventListener('input', checkMatch);
    confirmField.addEventListener('input', checkMatch);

    function validateForm() {
        if (pwField.value.length < 6) {
            pwField.focus();
            return false;
        }
        if (pwField.value !== confirmField.value) {
            confirmField.classList.add('error-field');
            confirmField.focus();
            return false;
        }
        return true;
    }
</script>

</body>
</html>
