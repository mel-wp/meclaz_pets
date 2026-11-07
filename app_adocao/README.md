# Meclaz Pets — aplicativo Flutter

Aplicativo móvel para visualizar animais disponíveis e enviar pedidos de adoção à API Dart/PostgreSQL.

## Executar no Android Emulator

1. Inicie o PostgreSQL, crie o banco e aplique `api_adocao/schema.sql` (veja o README da API).
2. Inicie a API a partir da pasta `api_adocao` com `dart run bin/api_adocao.dart`.
3. No emulador, `10.0.2.2` aponta para o computador host. Esse é o endereço padrão do app.
4. Na pasta `app_adocao`, rode:

```powershell
flutter pub get
flutter run
```

## Executar em celular físico

Conecte o celular e o computador à mesma rede Wi-Fi, permita a porta TCP `8080` no firewall do computador e descubra o IP local do computador. Rode:

```powershell
flutter run --dart-define=API_HOST=192.168.0.10
```

Troque `192.168.0.10` pelo IP real do computador. O servidor precisa estar ativo enquanto o app usa a API.

## Fluxo disponível

- Carrega apenas animais disponíveis e permite atualizar a lista.
- O botão **Adotar** solicita nome e e-mail/telefone.
- Envia um pedido à rota `POST /solicitacoes` e informa sucesso ou erro.
- A API valida se o animal ainda está disponível; pedidos aceitos ficam com status `pendente` no banco.
