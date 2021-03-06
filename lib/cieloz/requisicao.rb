require 'net/http'
require 'builder'

class Cieloz::Requisicao
  include Cieloz::Helpers

  attr_accessor :id, :versao
  attr_reader :dados_ec

  validates :dados_ec, presence: true

  def attributes
    { dados_ec: @dados_ec }
  end

  def to_xml
    x = Builder::XmlMarkup.new
    x.instruct!
    name = self.class.name.demodulize
    x.tag! name.underscore.dasherize, id: id, versao: versao do
      attributes.each { |attr, value|
        next if value.nil?

        unless value.respond_to? :attributes
          x.tag! dash(attr), value
        else
          x.tag! dash(attr) do
            value.attributes.each do |attr, value|
              x.tag!(dash(attr), value) unless value.blank?
            end
          end
        end
      }
    end
  end

  def submit
    @dados_ec = Cieloz::Configuracao.credenciais

    if valid?
      @id     = SecureRandom.uuid if id.blank?
      @versao = "1.2.0"           if versao.blank?

      http = Net::HTTP.new Cieloz::Configuracao.host, 443
      http.use_ssl = true
      http.open_timeout = 5 * 1000
      http.read_timeout = 30 * 1000
      http.ssl_version = :SSLv3 #http://stackoverflow.com/questions/11321403/openssl-trouble-with-ruby-1-9-3

      parse http.post Cieloz::Configuracao.path, "mensagem=#{to_xml}"
    end
  end

  def parse res
    body = res.body.force_encoding("ISO-8859-1").encode "UTF-8"
    return Erro.from(body).tap { |e| e.codigo = res.code } if res.code != "200"

    root = Nokogiri::XML(body).root
    response_class =  case root.name
    when 'erro'       then Erro
    when 'transacao'  then Transacao
    end
    response_class.from body
  end

  private
  def dash value
    value.to_s.gsub("@", "").dasherize
  end
end
