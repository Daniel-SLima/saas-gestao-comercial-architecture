-- ============================================================================
-- Arquitetura de Banco de Dados & Segurança (Supabase PostgreSQL + RLS)
-- Repositório complementar ao OrçaDemo (gerador_orcamentos_demo)
-- Autor: Daniel Santana Lima
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. Funções / Perfis reais do ecossistema (alinhado ao hook usePerfilUsuario)
CREATE TYPE public.funcao_usuario AS ENUM (
  'admin',
  'vendedor',
  'operador',
  'financeiro',
  'compras',
  'desativado'
);

CREATE TYPE public.status_orcamento AS ENUM (
  'Rascunho',
  'Em Análise',
  'Aprovado',
  'Em Produção',
  'Concluído',
  'Cancelado'
);

-- 2. Tabela perfis_usuarios (vinculada ao Supabase Auth)
CREATE TABLE public.perfis_usuarios (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nome TEXT NOT NULL,
  funcao public.funcao_usuario NOT NULL DEFAULT 'vendedor',
  setor TEXT, -- Preenchido quando funcao = 'operador' (ex: Corte, Montagem, Acabamento)
  alcada_desconto_max NUMERIC(5,2) NOT NULL DEFAULT 10.00,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Clientes e Produtos
CREATE TABLE public.clientes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  razao_social TEXT NOT NULL,
  documento TEXT UNIQUE NOT NULL,
  email TEXT,
  telefone TEXT,
  vendedor_responsavel UUID REFERENCES public.perfis_usuarios(user_id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.produtos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo TEXT UNIQUE NOT NULL,
  nome TEXT NOT NULL,
  setor_padrao TEXT NOT NULL DEFAULT 'Montagem',
  preco_unitario NUMERIC(12,2) NOT NULL CHECK (preco_unitario >= 0),
  ativo BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Orçamentos (com suporte a transferência entre vendedores e clonagem)
CREATE TABLE public.orcamentos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  numero_sequencial SERIAL UNIQUE,
  codigo TEXT UNIQUE NOT NULL,
  cliente_id UUID NOT NULL REFERENCES public.clientes(id),
  vendedor_id UUID NOT NULL REFERENCES public.perfis_usuarios(user_id),
  orcamento_origem_id UUID REFERENCES public.orcamentos(id), -- Rastreio de clonagem
  subtotal NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (subtotal >= 0),
  desconto_percentual NUMERIC(5,2) NOT NULL DEFAULT 0 CHECK (desconto_percentual >= 0 AND desconto_percentual <= 100),
  valor_liquido NUMERIC(12,2) GENERATED ALWAYS AS (
    ROUND(subtotal * (1 - desconto_percentual / 100.0), 2)
  ) STORED,
  status public.status_orcamento NOT NULL DEFAULT 'Em Análise',
  anexo_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. Itens do Orçamento (com coluna ordem_exibicao para reordenação manual)
CREATE TABLE public.orcamento_itens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  orcamento_id UUID NOT NULL REFERENCES public.orcamentos(id) ON DELETE CASCADE,
  produto_id UUID NOT NULL REFERENCES public.produtos(id),
  ordem_exibicao INTEGER NOT NULL DEFAULT 0,
  quantidade INTEGER NOT NULL CHECK (quantidade > 0),
  preco_unitario NUMERIC(12,2) NOT NULL CHECK (preco_unitario >= 0),
  observacao_tecnica TEXT
);

-- 6. Ordens de Produção organizadas por Setores
CREATE TABLE public.ordens_producao (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo_op TEXT UNIQUE NOT NULL,
  orcamento_id UUID NOT NULL REFERENCES public.orcamentos(id),
  setor_atual TEXT NOT NULL,
  operador_id UUID REFERENCES public.perfis_usuarios(user_id),
  concluido BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. Solicitações de Compras vinculadas à Produção
CREATE TABLE public.solicitacoes_compras (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ordem_producao_id UUID REFERENCES public.ordens_producao(id),
  insumo_descricao TEXT NOT NULL,
  quantidade NUMERIC(10,2) NOT NULL CHECK (quantidade > 0),
  status TEXT NOT NULL DEFAULT 'Pendente' CHECK (status IN ('Pendente', 'Cotando', 'Comprado', 'Recebido')),
  solicitado_por UUID REFERENCES public.perfis_usuarios(user_id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- Row Level Security (RLS) alinhado aos 6 perfis do sistema
-- ============================================================================
ALTER TABLE public.perfis_usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orcamentos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ordens_producao ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.solicitacoes_compras ENABLE ROW LEVEL SECURITY;

-- Bloqueia qualquer acesso de usuários com funcao = 'desativado'
CREATE OR REPLACE FUNCTION public.usuario_ativo()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.perfis_usuarios p
    WHERE p.user_id = auth.uid()
      AND p.funcao <> 'desativado'
  );
$$;

-- Leitura de orçamentos para usuários ativos (admin, vendedor, financeiro, operador)
CREATE POLICY "leitura_orcamentos_usuarios_ativos"
  ON public.orcamentos FOR SELECT
  TO authenticated
  USING (public.usuario_ativo());

-- Criação de orçamentos restrita a 'admin' e 'vendedor' respeitando alçada
CREATE POLICY "insercao_orcamentos_admin_vendedor"
  ON public.orcamentos FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.perfis_usuarios p
      WHERE p.user_id = auth.uid()
        AND p.funcao IN ('admin', 'vendedor')
        AND desconto_percentual <= p.alcada_desconto_max
    )
  );

-- Operador visualiza/atualiza Ordens de Produção do seu próprio setor (ou Admin livre)
CREATE POLICY "acesso_setorial_ordens_producao"
  ON public.ordens_producao FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.perfis_usuarios p
      WHERE p.user_id = auth.uid()
        AND (
          p.funcao IN ('admin', 'financeiro')
          OR (p.funcao = 'operador' AND p.setor = ordens_producao.setor_atual)
        )
    )
  );

-- Módulo de compras gerenciado por 'admin' e 'compras'
CREATE POLICY "gestao_solicitacoes_compras"
  ON public.solicitacoes_compras FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.perfis_usuarios p
      WHERE p.user_id = auth.uid()
        AND p.funcao IN ('admin', 'compras', 'operador')
    )
  );
