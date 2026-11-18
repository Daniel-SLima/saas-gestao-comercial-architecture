export type FuncaoUsuario =
  | "admin"
  | "vendedor"
  | "operador"
  | "financeiro"
  | "compras"
  | "desativado";

export interface ItemOrcamentoInput {
  id: string;
  nomeProduto: string;
  quantidade: number;
  precoUnitario: number;
  ordemExibicao: number;
}

export interface ResultadoCalculoOrcamento {
  subtotalBruto: number;
  valorDesconto: number;
  valorLiquido: number;
  itensOrdenados: ItemOrcamentoInput[];
}

const ALCADA_MAXIMA_DESCONTO: Record<FuncaoUsuario, number> = {
  admin: 30,
  financeiro: 15,
  vendedor: 10,
  operador: 0,
  compras: 0,
  desativado: 0,
};

/**
 * Valida permissões do perfil (alinhado ao usePerfilUsuario do OrçaDemo),
 * reordena itens por ordemExibicao e calcula subtotal e valor líquido.
 */
export function calcularOrcamentoComAlcada(
  itens: ItemOrcamentoInput[],
  descontoPercentual: number,
  funcao: FuncaoUsuario
): ResultadoCalculoOrcamento {
  if (funcao === "desativado") {
    throw new Error("Conta desativada: operação bloqueada.");
  }

  if (funcao !== "admin" && funcao !== "vendedor" && funcao !== "financeiro") {
    throw new Error(
      `Acesso negado (RBAC): o perfil '${funcao}' não possui permissão para emitir orçamentos.`
    );
  }

  if (descontoPercentual < 0 || descontoPercentual > 100) {
    throw new Error("Percentual de desconto inválido.");
  }

  const alcada = ALCADA_MAXIMA_DESCONTO[funcao];
  if (descontoPercentual > alcada) {
    throw new Error(
      `Alçada máxima excedida para o perfil '${funcao}' (máximo permitido: ${alcada}%).`
    );
  }

  const itensOrdenados = [...itens].sort(
    (a, b) => a.ordemExibicao - b.ordemExibicao
  );

  const subtotalBruto = itensOrdenados.reduce((acc, item) => {
    if (item.quantidade <= 0 || item.precoUnitario < 0) {
      throw new Error("Quantidade ou preço unitário inválido.");
    }
    return acc + item.quantidade * item.precoUnitario;
  }, 0);

  const subtotalArredondado = Math.round(subtotalBruto * 100) / 100;
  const valorDesconto =
    Math.round(subtotalArredondado * (descontoPercentual / 100) * 100) / 100;
  const valorLiquido =
    Math.round((subtotalArredondado - valorDesconto) * 100) / 100;

  return {
    subtotalBruto: subtotalArredondado,
    valorDesconto,
    valorLiquido,
    itensOrdenados,
  };
}

/**
 * Gera conteúdo CSV com BOM UTF-8 compatível com Microsoft Excel (pt-BR).
 */
export function exportarRelatorioExcelCsv(
  registros: Array<{
    codigo: string;
    cliente: string;
    vendedor: string;
    valorLiquido: number;
    status: string;
  }>
): string {
  const cabecalho = [
    "Codigo",
    "Cliente",
    "Vendedor",
    "Valor Liquido (BRL)",
    "Status",
  ];
  const linhas = registros.map((r) => [
    r.codigo,
    r.cliente.replace(/;/g, ","),
    r.vendedor.replace(/;/g, ","),
    r.valorLiquido.toFixed(2).replace(".", ","),
    r.status,
  ]);

  return (
    "\uFEFF" +
    [cabecalho.join(";"), ...linhas.map((l) => l.join(";"))].join("\r\n")
  );
}
