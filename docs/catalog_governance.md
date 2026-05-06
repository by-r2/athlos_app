# Governanca de Catalogo Athlos

> **Manutencao dos exercicios no codigo-fonte do app** (chave canonica em ingles, seed Drift, migracoes, ARB): ver [catalog_exercises.md](./catalog_exercises.md) (guia tecnico principal). Este ficheiro continua centrado na **matriz de conflitos** e no processo de governanca/import.

## Objetivo

Padronizar como conflitos de catalogo (exercicios e equipamentos) sao detectados no app, triados pela equipe, resolvidos no Supabase e aplicados nos dispositivos sem exigir release para cada incidente.

## Conceitos

- `import`: dados vindos de um arquivo JSON de backup.
- `local`: banco Drift do dispositivo do usuario.
- `remoto`: catalogo oficial no Supabase.
- `verified`: item oficial de catalogo.
- `nonVerified`: item custom criado pelo usuario.

## Matriz de decisao oficial

### verified vs verified

- Mesmo `catalogRemoteId` e mesmos dados: manter um registro.
- Mesmo `catalogRemoteId` e um item com mais campos: merge semantico, preservando o ID winner.
- `catalogRemoteId` diferentes com dados equivalentes: abrir pendencia de governanca (nao resolver automaticamente no app).
- Mesmo `catalogRemoteId` com dados divergentes: abrir pendencia de governanca.

### verified vs nonVerified

- Sempre exige confirmacao do usuario no import.
- Se confirmar equivalencia: manter `verified` como winner, remapear FKs do loser para winner, deletar loser somente se loser for `nonVerified`.
- Se recusar equivalencia: manter ambos.

### nonVerified vs nonVerified

- Match forte (nome normalizado igual ou contencao + compatibilidade semantica): auto-merge.
- Match ambiguo: pedir decisao do usuario.
- Se usuario confirmar equivalencia: merge + remap de FKs + delecao do loser.
- Se usuario negar: manter ambos.

## Auto-merge vs revisao obrigatoria

Auto-merge permitido quando:

- confianca de match alta;
- metadados semanticos compativeis (categoria para equipamento; grupo/tipo/padrao para exercicio);
- nenhum item `verified` conflitando com outro `verified` divergente.

Revisao obrigatoria quando:

- `verified` vs `nonVerified`;
- conflito `verified` vs `verified`;
- similaridade fuzzy sem confianca suficiente.

## Politica winner/loser e preservacao de ID

- Winner sempre preserva o ID.
- Todos os relacionamentos apontando para loser devem ser remapeados para winner em transacao unica.
- Itens `verified` nunca sao deletados automaticamente.

## Processo operacional (passo a passo)

1. **Deteccao no app**: import identifica conflitos e pendencias.
2. **Criacao de evento/pendencia**: app registra pendencia para decisao do usuario ou governanca.
3. **Triagem de governanca**: equipe avalia pendencias criticas (`verified` vs `verified`).
4. **Publicacao de regra no Supabase**: ajuste em tabelas oficiais (nome, mapeamento, alias, relacoes).
5. **Aplicacao no sync**: clientes baixam nova versao de catalogo e aplicam reconciliacao local.
6. **Auditoria e encerramento**: validar estado final e fechar incidente.

## Estrategia multi-device com Supabase

- O app grava conflitos criticos em `catalog_governance_events` (outbox local).
- No sync, o cliente envia eventos pendentes para `catalog_governance_events` no Supabase.
- A equipe publica regras em `catalog_governance_rules` com `rule_version` incremental.
- Cada dispositivo aplica regras de forma idempotente e registra em `catalog_governance_applied_rules`.
- O cliente guarda a ultima versao aplicada para evitar reprocessar regras antigas.
- Remapeamentos locais nunca deletam item `verified`; apenas redirecionam referencias para o winner.

## Checklist pos-resolucao

- Catalogo remoto atualizado e versionado.
- Sync aplicado em dispositivo limpo e dispositivo com dados legados.
- Nenhum FK quebrado apos remap.
- Nenhum item `verified` removido automaticamente.
- Resultado do import coerente com decisoes do usuario.

## Rollback seguro

1. Reverter alteracoes do catalogo remoto para a versao anterior.
2. Incrementar `catalog_version` com correcao de rollback.
3. Publicar script de reconciliacao reversa (se houve remap incorreto).
4. Rodar sync em staging e validar checklist.
5. Liberar rollback para producao.

## Versionamento de regras

- Toda alteracao de governanca deve incrementar `catalog_version`.
- Mudancas de conteudo (nome, vinculo, equivalencia) vao por sync.
- Mudancas de engine (algoritmo, schema, UX) vao por release de app.
