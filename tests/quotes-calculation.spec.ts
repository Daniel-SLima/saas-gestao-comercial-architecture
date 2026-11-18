import assert from "node:assert/strict";
import test from "node:test";
import {
  calcularOrcamentoComAlcada,
  exportarRelatorioExcelCsv,
} from "../src/services/exportService.ts";

test("reordena itens por ordemExibicao e calcula líquido com 5% para vendedor", () => {
  const res = calcularOrcamentoComAlcada(
    [
      {
        id: "2",
        nomeProduto: "Módulo Auxiliar",
        quantidade: 2,
        precoUnitario: 500,
        ordemExibicao: 2,
      },
      {
        id: "1",
        nomeProduto: "Painel Principal",
        quantidade: 10,
        precoUnitario: 1150,
        ordemExibicao: 1,
      },
    ],
    5,
    "vendedor"
  );

  assert.equal(res.itensOrdenados[0].id, "1");
  assert.equal(res.subtotalBruto, 12500);
  assert.equal(res.valorDesconto, 625);
  assert.equal(res.valorLiquido, 11875);
});

test("bloqueia desconto acima de 10% para perfil vendedor e bloqueia perfil operador/desativado", () => {
  assert.throws(
    () =>
      calcularOrcamentoComAlcada(
        [{ id: "1", nomeProduto: "Item", quantidade: 1, precoUnitario: 1000, ordemExibicao: 1 }],
        20,
        "vendedor"
      ),
    /Alçada máxima excedida/
  );

  assert.throws(
    () =>
      calcularOrcamentoComAlcada(
        [{ id: "1", nomeProduto: "Item", quantidade: 1, precoUnitario: 1000, ordemExibicao: 1 }],
        0,
        "operador"
      ),
    /Acesso negado \(RBAC\)/
  );

  assert.throws(
    () =>
      calcularOrcamentoComAlcada(
        [{ id: "1", nomeProduto: "Item", quantidade: 1, precoUnitario: 1000, ordemExibicao: 1 }],
        0,
        "desativado"
      ),
    /Conta desativada/
  );
});

test("gera CSV com BOM UTF-8 e separador ponto-e-vírgula compatível com Excel", () => {
  const csv = exportarRelatorioExcelCsv([
    {
      codigo: "ORC-2026-041",
      cliente: "Indústria Baiana Ltda",
      vendedor: "Daniel",
      valorLiquido: 11875,
      status: "Em Produção",
    },
  ]);

  assert.ok(csv.startsWith("\uFEFF"));
  assert.ok(
    csv.includes("ORC-2026-041;Indústria Baiana Ltda;Daniel;11875,00;Em Produção")
  );
});
