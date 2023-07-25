with cte_cliente_empresa as (
select distinct 
			ce.nm_cliente_empresa_nome_fantasia "Nome"
			, ce.cd_cliente_empresa_numero_documento "CPF/CNPJ"
			, ce.tx_cliente_empresa_razao_social "Razão social"
			, p.nm_pessoa_nome "Responsável"
			, dcec.ds_entidade "Entidade"
			, dco.tx_operadora_nome_fantasia "Operadora"
			, dcb.ds_beneficio "Benefício"
			, dcp.cd_produto_operadora "Contrato"
			, dcp.ds_produto "Produto"
			, dca.ds_acomodacao "Acomodação"
			, to_char(cp.dt_contrato_produto_data_vigencia_inicio, 'dd/MM/yyyy') "Início de vigência do plano"
			, to_char(cp.dt_contrato_produto_data_vigencia_fim, 'dd/MM/yyyy') "Fim de vigência do plano"
--			, cc.id_contrato_cliente
--			, cp.id_contrato_produto
			, case when cp.dt_contrato_produto_data_vigencia_fim is null or cp.dt_contrato_produto_data_vigencia_fim::date >= now()::date is null then 'Ativa' else 'Inativa' end "Situação cadastral"
			, to_char(cp.dt_contrato_produto_base_reajuste, 'MM') "Mês de reajuste"
			, ce.id_cliente_empresa
from		cliente_empresa ce 
inner join	contrato_cliente cc					on	cc.id_cliente_empresa = ce.id_cliente_empresa
inner join	familia f 							on	f.id_contrato_cliente = cc.id_contrato_cliente and not f.fl_familia_demitido_aposentado
inner join	contrato_produto cp 				on	cp.id_contrato_cliente = cc.id_contrato_cliente
inner join 	dms_cadbase_entidade_classe dcec	on	dcec.id_entidade_classe = cc.id_entidade
inner join	dms_cadbase_produto dcp  			on	dcp.id_produto = cp.id_produto 
inner join	dms_cadbase_acomodacao dca 			on	dca.id_acomodacao = cp.id_acomodacao 
inner join 	dms_cadbase_operadora dco 			on	dco.id_operadora = dcp.id_operadora 
inner join	dms_cadbase_beneficio dcb 			on	dcb.id_beneficio = dcp.id_beneficio 
left join	socio_responsavel_empresa sre 		on	sre.id_cliente_empresa = ce.id_cliente_empresa 
												and now()::date between sre.dt_socio_responsavel_empresa_data_vigencia_fim::date and coalesce(sre.dt_socio_responsavel_empresa_data_vigencia_fim, now())::date 
left join 	pessoa p							on	p.id_pessoa = sre.id_pessoa
where		true
and 		$X{IN, dcp.id_produto, Produtos}
and 		$X{IN, dco.id_operadora, Operadoras}
and 		$X{IN, dcec.id_entidade_classe, Entidades}
)

, cte_contato_cliente_empresa as (
select distinct on(ce.id_cliente_empresa, cec.cd_cliente_empresa_contato_tipo_registro)
			ce.id_cliente_empresa 
			, ce."Nome"
			, cec.cd_cliente_empresa_contato_tipo_registro 
			, cet.tx_cliente_empresa_telefone_numero_telefone 
			, cee.tx_cliente_empresa_email_endereco_email 
from		cte_cliente_empresa ce
inner join	cliente_empresa_contato cec 	on	cec.id_cliente_empresa = ce.id_cliente_empresa 
											and cec.dt_cliente_empresa_contato_exclusao is null
left join	cliente_empresa_telefone cet	on	cet.id_cliente_empresa_contato = cec.id_cliente_empresa_contato 
											and cet.dt_cliente_empresa_telefone_exclusao is null 
											and coalesce(cet.tx_cliente_empresa_telefone_numero_telefone, '') <> ''
											and cet.tx_cliente_empresa_telefone_numero_telefone <> '0000000000'
left join	cliente_empresa_email cee 		on	cee.id_cliente_empresa_contato = cec.id_cliente_empresa_contato 
											and cee.dt_cliente_empresa_email_exclusao is null
											and	coalesce(cee.tx_cliente_empresa_email_endereco_email, '') <> ''
											and cee.tx_cliente_empresa_email_endereco_email not ilike '%naotem%'
order by 	ce.id_cliente_empresa 
			, cec.cd_cliente_empresa_contato_tipo_registro 
			, cec.id_cliente_empresa_contato desc
			, case cet.cd_cliente_empresa_telefone_tipo_telefone 
				when 'CELULAR' then 1
				when 'TELEFONE_FIXO' then 2
				else 3
			end
			, cee.id_cliente_empresa_email desc
)

, cte_titular_demitido_aposentado as (
select distinct on (f.id_familia, cp.id_produto, cp.id_acomodacao)
			f.id_familia
			, cc.id_entidade
			, cc.id_cliente_empresa
			, cp.id_produto
			, cp.id_acomodacao
			, cp.dt_contrato_produto_base_reajuste
			, vfp.dt_vida_familia_produto_data_vigencia_inicio 
			, vfp.dt_vida_familia_produto_data_vigencia_fim
from		familia f
inner join	vida_familia vf				on	vf.id_familia = f.id_familia and vf.id_parentesco = 1
inner join	pessoa p 					on	p.id_pessoa = vf.id_pessoa
inner join	vida_familia_produto vfp	on	vfp.id_vida_familia = vf.id_vida_familia
inner join	contrato_cliente cc			on	cc.id_contrato_cliente = f.id_contrato_cliente
inner join	contrato_produto cp 		on	cp.id_contrato_produto = vfp.id_contrato_produto 
where		f.fl_familia_demitido_aposentado
and 		(
				f.dt_familia_data_demitido_aposentado is null
			or 	vfp.dt_vida_familia_produto_data_vigencia_inicio > f.dt_familia_data_demitido_aposentado
			or 	f.dt_familia_data_demitido_aposentado between vfp.dt_vida_familia_produto_data_vigencia_inicio and coalesce(vfp.dt_vida_familia_produto_data_vigencia_fim, f.dt_familia_data_demitido_aposentado)
			)
and 		$X{IN, cp.id_produto, Produtos}
and 		$X{IN, cp.id_operadora, Operadoras}
and 		$X{IN, cc.id_entidade, Entidades}
order by	f.id_familia
			, cp.id_produto
			, cp.id_acomodacao
			, case 
				when vfp.dt_vida_familia_produto_data_vigencia_inicio > f.dt_familia_data_demitido_aposentado then 1
				when f.dt_familia_data_demitido_aposentado between vfp.dt_vida_familia_produto_data_vigencia_inicio and coalesce(vfp.dt_vida_familia_produto_data_vigencia_fim, f.dt_familia_data_demitido_aposentado) then 2
				else 3
			end
			, vfp.dt_vida_familia_produto_data_vigencia_fim desc nulls first
			, vfp.dt_vida_familia_produto_data_vigencia_inicio
)

, cte_demitido_aposentado as (
select distinct on (tda.id_familia, dcp.id_produto)
			ce.tx_cliente_empresa_razao_social "Razão social empresa"
			, p2.nm_pessoa_nome "Responsável"
			, dcec.ds_entidade "Entidade"
			, dco.tx_operadora_nome_fantasia "Operadora"
			, dcb.ds_beneficio "Benefício"
			, dcp.cd_produto_operadora "Contrato"
			, dcp.ds_produto "Produto"
			, dca.ds_acomodacao "Acomodação"
			, to_char(tda.dt_vida_familia_produto_data_vigencia_inicio, 'dd/MM/yyyy') "Início de vigência do plano"
			, to_char(tda.dt_vida_familia_produto_data_vigencia_fim, 'dd/MM/yyyy') "Fim de vigência do plano"
			, case when tda.dt_vida_familia_produto_data_vigencia_fim is null or tda.dt_vida_familia_produto_data_vigencia_fim::date >= now()::date then 'Ativo' else 'Inativo' end "Situação cadastral"
			, to_char(tda.dt_contrato_produto_base_reajuste, 'MM') "Mês de reajuste"
			, tda.id_familia
			, rff.id_responsavel_financeiro
from		cte_titular_demitido_aposentado tda
inner join	cliente_empresa ce 					on	ce.id_cliente_empresa = tda.id_cliente_empresa 
inner join 	dms_cadbase_entidade_classe dcec	on	dcec.id_entidade_classe = tda.id_entidade 
inner join	dms_cadbase_produto dcp  			on	dcp.id_produto = tda.id_produto 
inner join	dms_cadbase_acomodacao dca 			on	dca.id_acomodacao = tda.id_acomodacao 
inner join 	dms_cadbase_operadora dco 			on	dco.id_operadora = dcp.id_operadora 
inner join	dms_cadbase_beneficio dcb 			on	dcb.id_beneficio = dcp.id_beneficio 
inner join 	responsavel_financeiro_familia rff 	on	rff.id_familia = tda.id_familia
left join	socio_responsavel_empresa sre 		on	sre.id_cliente_empresa = ce.id_cliente_empresa
left join 	pessoa p2 							on	p2.id_pessoa = sre.id_pessoa
order by 	tda.id_familia
			, dcp.id_produto
			, rff.dt_vigencia_fim desc nulls first
			, rff.dt_vigencia_inicio desc
)

, cte_contato_responsavel_financeiro_pessoa as (
select distinct on (da.id_familia, coalesce(fc.cd_familia_contato_tipo_registro, 'CONTATO_RESPONSAVEL'))
			da.id_familia 
			, (vf.id_vida_familia is not null) rf_vida_familia
			, coalesce(fc.cd_familia_contato_tipo_registro, 'CONTATO_RESPONSAVEL') contato_tipo_registro
			, case 
				when vf.id_vida_familia is not null then p2.nm_pessoa_nome
				else p.nm_pessoa_nome
			end nm_pessoa_nome
			, case 
				when vf.id_vida_familia is not null then p2.cd_pessoa_cpf 
				else p.cd_pessoa_cpf
			end cd_pessoa_cpf
			, case 
				when vf.id_vida_familia is not null then ft.tx_familia_telefone_numero_telefone 
				else rf.tx_responsavel_financeiro_telefone
			end telefone
			, case 
				when vf.id_vida_familia is not null then fe.tx_familia_email_endereco_email
				else rf.tx_responsavel_financeiro_email
			end email
from		cte_demitido_aposentado da
inner join	responsavel_financeiro rf 	on	rf.id_responsavel_financeiro = da.id_responsavel_financeiro 
inner join	pessoa p 					on	p.id_pessoa = rf.id_pessoa 
left join	vida_familia vf 			on	vf.id_pessoa = p.id_pessoa and vf.id_familia = da.id_familia and vf.id_parentesco = 1
left join	pessoa p2					on	p2.id_pessoa = vf.id_pessoa
left join	familia_contato fc 			on	fc.id_familia = da.id_familia and vf.id_vida_familia is not null
										and fc.dt_familia_contato_exclusao is null
left join	familia_telefone ft 		on	ft.id_familia_contato = fc.id_familia_contato 
										and ft.dt_familia_telefone_exclusao is null
										and coalesce(ft.tx_familia_telefone_numero_telefone, '0000000000') <> '0000000000'
left join	familia_email fe 			on	fe.id_familia_contato = fc.id_familia_contato 
										and fe.dt_familia_email_exclusao is null
										and	coalesce(fe.tx_familia_email_endereco_email, 'naotem') not ilike '%naotem%'
order by 	da.id_familia
			, coalesce(fc.cd_familia_contato_tipo_registro, 'CONTATO_RESPONSAVEL')
			, case ft.cd_familia_telefone_tipo_telefone 
				when 'CELULAR' then 1
				when 'TELEFONE_FIXO' then 2
				else 3
			end
			, fe.id_familia_email desc
)			
			
, cte_contato_responsavel_financeiro_cliente_empresa as (
select distinct on (da.id_familia, cec.cd_cliente_empresa_contato_tipo_registro)
			da.id_familia 
			, cec.cd_cliente_empresa_contato_tipo_registro
			, ce.nm_cliente_empresa_nome_fantasia
			, ce.cd_cliente_empresa_numero_documento 
			, cet.tx_cliente_empresa_telefone_numero_telefone telefone
			, cee.tx_cliente_empresa_email_endereco_email email
from		cte_demitido_aposentado da
inner join	responsavel_financeiro rf 		on	rf.id_responsavel_financeiro = da.id_responsavel_financeiro 
inner join	cliente_empresa ce 				on	ce.id_cliente_empresa = rf.id_cliente_empresa
inner join	cliente_empresa_contato cec 	on	cec.id_cliente_empresa = ce.id_cliente_empresa 
											and cec.dt_cliente_empresa_contato_exclusao is null
left join	cliente_empresa_telefone cet	on	cet.id_cliente_empresa_contato = cec.id_cliente_empresa_contato 
											and cet.dt_cliente_empresa_telefone_exclusao is null 
											and coalesce(cet.tx_cliente_empresa_telefone_numero_telefone, '') <> ''
											and cet.tx_cliente_empresa_telefone_numero_telefone <> '0000000000'
left join	cliente_empresa_email cee 		on	cee.id_cliente_empresa_contato = cec.id_cliente_empresa_contato 
											and cee.dt_cliente_empresa_email_exclusao is null
											and	coalesce(cee.tx_cliente_empresa_email_endereco_email, '') <> ''
											and cee.tx_cliente_empresa_email_endereco_email not ilike '%naotem%'
order by 	da.id_familia 
			, cec.cd_cliente_empresa_contato_tipo_registro 
			, cec.id_cliente_empresa_contato desc
			, case cet.cd_cliente_empresa_telefone_tipo_telefone 
				when 'CELULAR' then 1
				when 'TELEFONE_FIXO' then 2
				else 3
			end
			, cee.id_cliente_empresa_email desc
)

select distinct
			ce."Nome"
			, ce."CPF/CNPJ"
			, ce."Razão social"
			, ce."Responsável"
			, cce1.tx_cliente_empresa_email_endereco_email "E-mail contato cobrança"
			, cce2.tx_cliente_empresa_email_endereco_email "E-mail contato principal"
			, cce3.tx_cliente_empresa_email_endereco_email "E-mail contato secundário"
			, cce1.tx_cliente_empresa_telefone_numero_telefone "Telefone contato cobrança"
			, cce2.tx_cliente_empresa_telefone_numero_telefone "Telefone contato principal"
			, cce3.tx_cliente_empresa_telefone_numero_telefone "Telefone contato secundário"
			, ce."Entidade"
			, ce."Operadora"
			, ce."Benefício"
			, ce."Contrato"
			, ce."Produto"
			, ce."Acomodação"
			, ce."Início de vigência do plano"
			, ce."Fim de vigência do plano"
			, ce."Situação cadastral"
			, ce."Mês de reajuste"
from		cte_cliente_empresa ce
left join	cte_contato_cliente_empresa cce1	on	cce1.id_cliente_empresa = ce.id_cliente_empresa and cce1.cd_cliente_empresa_contato_tipo_registro = 'COBRANCA'
left join	cte_contato_cliente_empresa cce2	on	cce2.id_cliente_empresa = ce.id_cliente_empresa and cce2.cd_cliente_empresa_contato_tipo_registro = 'CONTATO_PRINCIPAL'
left join	cte_contato_cliente_empresa cce3	on	cce3.id_cliente_empresa = ce.id_cliente_empresa and cce3.cd_cliente_empresa_contato_tipo_registro = 'CONTATO_SECUNDARIO'		
union
select distinct	
			coalesce(crfp1.nm_pessoa_nome, crfp2.nm_pessoa_nome, crfp4.nm_pessoa_nome, crfce1.nm_cliente_empresa_nome_fantasia) "Nome"
			, coalesce(crfp1.cd_pessoa_cpf, crfp2.cd_pessoa_cpf, crfp4.cd_pessoa_cpf, crfce1.cd_cliente_empresa_numero_documento) "CPF/CNPJ"
			, da."Razão social empresa"
			, da."Responsável"
			, case when crfp4.id_familia is null then coalesce(crfp1.email, crfce1.email) else crfp4.email end "E-mail contato cobrança"
			, coalesce(crfp2.email, crfce2.email) "E-mail contato principal"
			, coalesce(crfp3.email, crfce3.email) "E-mail contato secundário"
			, case when crfp4.id_familia is null then coalesce(crfp1.telefone, crfce1.telefone) else crfp4.telefone end "Telefone contato cobrança"
			, coalesce(crfp2.telefone, crfce2.telefone) "Telefone contato principal"
			, coalesce(crfp3.telefone, crfce3.telefone) "Telefone contato secundário"
			, da."Entidade"
			, da."Operadora"
			, da."Benefício"
			, da."Contrato"
			, da."Produto"
			, da."Acomodação"
			, da."Início de vigência do plano"
			, da."Fim de vigência do plano"
			, da."Situação cadastral"
			, da."Mês de reajuste"
from 		cte_demitido_aposentado da
left join	cte_contato_responsavel_financeiro_pessoa crfp1				on	crfp1.id_familia = da.id_familia and crfp1.contato_tipo_registro = 'COBRANCA'
left join	cte_contato_responsavel_financeiro_pessoa crfp2				on	crfp2.id_familia = da.id_familia and crfp2.contato_tipo_registro = 'CONTATO_PRINCIPAL'
left join	cte_contato_responsavel_financeiro_pessoa crfp3				on	crfp3.id_familia = da.id_familia and crfp3.contato_tipo_registro = 'CONTATO_SECUNDARIO'
left join	cte_contato_responsavel_financeiro_pessoa crfp4				on	crfp4.id_familia = da.id_familia and crfp4.contato_tipo_registro = 'CONTATO_RESPONSAVEL'
left join 	cte_contato_responsavel_financeiro_cliente_empresa crfce1	on	crfce1.id_familia = da.id_familia and crfce1.cd_cliente_empresa_contato_tipo_registro = 'COBRANCA'
left join 	cte_contato_responsavel_financeiro_cliente_empresa crfce2	on	crfce2.id_familia = da.id_familia and crfce2.cd_cliente_empresa_contato_tipo_registro = 'CONTATO_PRINCIPAL'
left join 	cte_contato_responsavel_financeiro_cliente_empresa crfce3	on	crfce3.id_familia = da.id_familia and crfce3.cd_cliente_empresa_contato_tipo_registro = 'CONTATO_SECUNDARIO'
order by	"Razão social"
			, "CPF/CNPJ"
			, "Nome"
