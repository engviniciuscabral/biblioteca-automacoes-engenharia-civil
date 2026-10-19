# Python — Catálogo de automações

Scripts Python voltados a cálculos e aplicações de engenharia civil.

[← Voltar ao catálogo geral](../README.md)

## Índice de rotinas

| Arquivo | Finalidade | Interface |
|---|---|---|
| [`hut_goinfra.py`](./hut_goinfra.py) | Cálculo e visualização de hidrogramas unitários triangulares e hidrograma de projeto, conforme critérios implementados com referência à GOINFRA IP-03/2023. | Gráfica (Tkinter) |

## 1. hut_goinfra.py

**Objetivo:** apoiar cálculos hidrológicos de bacias com geração e visualização do Hidrograma Unitário Triangular (HUT), chuvas efetivas e hidrograma resultante.

**Funcionamento:** o programa recebe área da bacia (km²), tempo de concentração (h), Curve Number (CN), tempo de retorno (anos) e quatro valores de precipitação acumulada. Calcula parâmetros do HUT, aplica redução espacial da chuva, estima precipitação efetiva pelo método SCS/CN e combina quatro hidrogramas parciais, apresentando resultados em tabelas e gráficos.

**Como utilizar:**

1. Instale Python 3 e as dependências NumPy e Matplotlib.
2. Execute no terminal, a partir desta pasta:

   ```bash
   python -m pip install numpy matplotlib
   python hut_goinfra.py
   ```

3. Preencha ou revise os dados da interface e acione o cálculo.
4. Verifique unidades, parâmetros, resultados e gráficos antes de utilizar os valores em um projeto.

**Requisitos e dependências:** Python 3, `numpy`, `matplotlib` e `tkinter` (normalmente incluído em instalações convencionais de Python para Windows; pode exigir instalação separada em alguns sistemas). A aplicação utiliza a integração Matplotlib/Tkinter e requer ambiente gráfico.

**Status:** código disponibilizado no repositório; sintaxe Python verificada, mas interface e resultados numéricos não foram validados por execução nesta revisão.

**Limitações e cuidados:**

- **O cálculo completo está implementado somente para área superior a 20 km² e tempo de concentração inferior a 24 horas.** Para outras faixas, o programa informa o critério selecionado, mas não executa o cálculo completo.
- As precipitações fornecidas devem ser **acumuladas e não decrescentes**; o código verifica incrementos negativos de precipitação efetiva.
- O método de redução espacial da chuva e as expressões hidrológicas devem ser conferidos em relação às normas, hipóteses e dados adotados no projeto.
- Os campos possuem valores iniciais de exemplo; substitua-os pelos dados reais.
- O nome GOINFRA IP-03/2023 identifica a referência apresentada na interface do código, **não uma validação independente de conformidade normativa**.

[↑ Voltar ao índice](#índice-de-rotinas)

---

> Documentação elaborada a partir da leitura do código. Resultados, compatibilidade e aderência aos critérios normativos devem ser verificados antes do uso profissional.
