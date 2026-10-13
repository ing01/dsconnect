// Os dois públicos que o mesmo app atende - ver o plano em
// "App Mobile (Flutter): Colaborador + Cliente". Um só formulário de login
// decide sozinho qual dos dois é, tentando autenticar como colaborador
// primeiro (ver AuthRepository.login).
enum AuthMode { agent, client }
