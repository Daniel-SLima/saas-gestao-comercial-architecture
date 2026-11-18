# Arquitetura Backend, SQL & RLS — Sistema SaaS de Gestão Comercial e Produção

<div align="center">

**Modelagem Relacional PostgreSQL, Row Level Security (Supabase) e Testes de Regras de Negócio**

[![OrçaDemo Online](https://img.shields.io/badge/Front--End_Demo-OrçaDemo_Online-4F46E5?style=flat&logo=vercel&logoColor=white)](https://gerador-orcamentos-demo.vercel.app)
[![Repo Demo UI](https://img.shields.io/badge/Repositório_UI-gerador__orcamentos__demo-181717?style=flat&logo=github&logoColor=white)](https://github.com/Daniel-SLima/gerador_orcamentos_demo)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Supabase_RLS-3ECF8E?logo=supabase&logoColor=white)
![TypeScript](https://img.shields.io/badge/TypeScript-5-3178C6?logo=typescript&logoColor=white)

</div>

---

## Como este repositório se conecta ao **OrçaDemo**?

Eu desenvolvo e mantenho em produção um **Sistema SaaS de Gestão Comercial, Orçamentos, Produção e Compras**. Para apresentá-lo com segurança ao mercado sem expor infraestrutura ou dados de clientes reais, dividi a vitrine pública em **duas frentes complementares**:

1. **[OrçaDemo (`gerador_orcamentos_demo`)](https://github.com/Daniel-SLima/gerador_orcamentos_demo):** Demonstração pública da interface completa em Next.js + React + Tailwind + geração de PDFs (`OrcamentoPDF`, `OrdemProducaoPDF`, `OrdemProducaoFinanceiroPDF`), utilizando `localStorage` para isolamento total de dados ([Testar Online](https://gerador-orcamentos-demo.vercel.app)).
2. **Este repositório (`saas-gestao-comercial-architecture`):** Demonstra a **engenharia de dados, segurança por perfis (RBAC + RLS no PostgreSQL/Supabase) e testes automatizados** que sustentam a operação real em nuvem.

---

## Destaques de Engenharia

- **6 Perfis de Acesso (`perfis_usuarios`):** `admin`, `vendedor`, `operador` (vinculado ao seu `setor`), `financeiro`, `compras` e bloqueio imediato para `desativado` via função `SECURITY DEFINER` no PostgreSQL.
- **Módulos Relacionais Completos:**
  - `clientes` & `produtos` (com `setor_padrao`)
  - `orcamentos` (rastreio de clonagem via `orcamento_origem_id`, transferência entre vendedores e coluna calculada `valor_liquido`)
  - `orcamento_itens` (com `ordem_exibicao` para reordenação manual dos itens)
  - `ordens_producao` (isolamento setorial para operadores) e `solicitacoes_compras`
- **Regras Financeiras e Exportação Testadas:** Serviço em TypeScript validando alçada de desconto por função, ordenação de itens e geração de relatórios `.CSV` com BOM UTF-8 para Microsoft Excel.

---

## Estrutura

```text
saas-gestao-comercial-architecture/
├── supabase/
│   └── migrations/
│       └── 001_initial_schema_and_rls.sql
├── src/
│   └── services/
│       └── exportService.ts
├── tests/
│   └── quotes-calculation.spec.ts
└── package.json
```

---

## Executando os Testes Automatizados

Requer **Node.js 22+**:

```bash
npm test
```
