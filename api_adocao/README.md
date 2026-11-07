# API Meclaz Pets

API REST em Dart com PostgreSQL para consultar animais e registrar pedidos de adoção.

## Requisitos

- Dart SDK compatível com `pubspec.yaml` (Dart 3.12.2 ou superior)
- PostgreSQL instalado e ativo

## Preparar o banco

No PostgreSQL, crie o banco `meclaz_pets`. Depois, conecte-se a ele e execute o conteúdo de `schema.sql`. Exemplo no `psql`:

```sql
CREATE DATABASE meclaz_pets;
```

```powershell
psql -U postgres -d meclaz_pets -f .\schema.sql
```

Opcionalmente, inclua animais de demonstração:

```sql
INSERT INTO animais (nome, especie, idade_em_meses) VALUES
('Luna', 'Cachorro', 8),
('Mingau', 'Gato', 14),
('Pipoca', 'Coelho', 5);
```

## Iniciar a API

No diretório `api_adocao`:

```powershell
dart pub get
dart run bin/api_adocao.dart
```

Digite a senha do usuário PostgreSQL `postgres` quando solicitado. O servidor escuta na porta `8080` em todas as interfaces de rede, para permitir acesso do emulador/celular.

## Rotas

### `GET /animais`

Retorna todos os animais. Use `GET /animais?disponivel=true` para filtrar os disponíveis.

### `POST /animais`

Registra um animal disponível. JSON:

```json
{"nome":"Luna","especie":"Cachorro","idade_em_meses":8}
```

### `POST /solicitacoes`

Cria um pedido pendente para um animal disponível. JSON:

```json
{"animal_id":1,"nome_interessado":"Ana Silva","contato":"ana@email.com"}
```

Respostas de criação: `201 Created`; dados inválidos ou animal indisponível: `400 Bad Request`; rota inexistente: `404 Not Found`.
