#
# Assignment:
#
# Implement the methods as specified in the following class, plus any you need to use to make your life easier.
# Make explicit any dependencies on external libraries so that I can run your code locally.
#
# Los Angeles recently sampled water quality at various sites, and recorded the
# presence of contaminants. Here's an excerpt of the table:
# (from: http://file.lacounty.gov/bc/q3_2010/cms1_148456.pdf)
# (All chemical values are in mg/L)
# | id | site                                      | chloroform | bromoform | bromodichloromethane | dibromichloromethane |
# |  1 | LA Aqueduct Filtration Plant Effluent     |   .00104   | .00000    |  .00149              |  .00275              |
# |  2 | North Hollywood Pump Station (well blend) |   .00291   | .00487    |  .00547              |  .0109               |
# |  3 | Jensen Plant Effluent                     |   .00065   | .00856    |  .0013               |  .00428              |
# |  4 | Weymouth Plant Effluent                   |   .00971   | .00317    |  .00931              |  .0116               |
#
# These four chemical compounds are collectively regulated by the EPA as Trihalomethanes,
# and their collective concentration cannot exceed .080 mg/L
#
# (from http://water.epa.gov/drink/contaminants/index.cfm#List )
require 'mysql'
class WaterSample
  # This class intends to ease the managing of the collected sample data,
  # and assist in computing factors of the data.
  #
  # The schema it must interact with and some sample data should be delivered
  # with your assignment as a MySQL dump

  def initialize(result_hash = {})
    @id = result_hash["id"] || nil
    @site = result_hash["site"] || nil
    @chloroform = (result_hash["chloroform"] && result_hash["chloroform"].to_f) || nil
    @bromoform = (result_hash["bromoform"] && result_hash["bromoform"].to_f) || nil
    @bromodichloromethane = (result_hash["bromodichloromethane"] && result_hash["bromodichloromethane"].to_f) || nil
    @dibromichloromethane = (result_hash["dibromichloromethane"] && result_hash["dibromichloromethane"].to_f) || nil
  end

  self.class_eval do
    con = Mysql.new('localhost', 'root', '', 'factor_hw')
    result = con.list_fields("water_samples")
    fields = result.fetch_fields
    fields.each do |field|
      define_method(field.name.to_sym) do
        instance_variable_get(('@' + field.name).to_sym)
      end
    end
    con.close
  end

  def self.find(sample_id)
    con = Mysql.new('localhost', 'root', '', 'factor_hw')
    rs = con.query("select * from water_samples where id = #{sample_id}")
    result = rs.fetch_hash
    con.close
    water_sample = self.new(result)
    return water_sample

    # spec
    # sample2 = WaterSample.find(2)
    # expect(sample2.site).to eq("North Hollywood Pump Station (well blend)")
    # expect(sample2.chloroform).to eq(0.00291)
    # expect(sample2.bromoform).to eq(0.00487)
    # expect(sample2.bromodichloromethane).to eq(0.00547)
    # expect(sample2.dibromichloromethane).to eq(0.0109)

  end

  # Some Trihalomethanes are nastier than others, bromodichloromethane and
  # bromoform are particularly bad. That is, water that has .060 mg/L of
  # Bromoform is generally more dangerous than water that has .060 mg/L of
  # Chloroform, though both are considered "safe enough".
  #
  # We could build a better metric by adjusting the contribution of each
  # component to the Trihalomethane limit based on it's relative "danger".
  # Furthermore, consider we want to try several different combinations of
  # weights (factors).
  #
  # Sample table of Factor weights:
  # |  id   | chloroform_weight | bromoform_weight | bromodichloromethane_weight | dibromichloromethane_wieight |
  # |   1   |   0.8             |      1.2         |       1.5                   |     0.7                      |
  # |   2   |   1.0             |      1.0         |       1.0                   |     1.0                      |
  # |   3   |   0.9             |      1.1         |       1.3                   |     0.6                      |
  # |   4   |   0.0             |      1.0         |       1.0                   |     1.7                      |
  #
  # In statistics, a factor is a single value representing a combination of
  # several component values. We may gather several different variables, which
  # semantically indicate a similar idea, and, to make analysis simpler, we can
  # combine these several values into a single "factor" and disregard the
  # constituents
  #
  # The weights that we should use in our factor could be a complex question.
  # Ultimately it depends on what we're modeling.
  #
  # For example, let's say the city has the option of installing one of several
  # different filtration units to remove a specific Triahlomethane (but the city
  # can't afford all of the filters). We can use differently weighted factors to
  # simulate each of these and do a cost / benefit analysis informing the city's
  # decision on which filtration unit to purchase.
  #
  # Let's say someone from the city has already computed various factors they
  # want to analyze, and put them in a factor_weights table.
  # In our case, we'll use a linear combination of the nth factor weights to compute the
  # samples nth factor.
  #
  #
  #
  # Return the value of the computed factor with id of factor_weights_id
  def factor(factor_weights_id)
    con = Mysql.new('localhost', 'root', '', 'factor_hw')
    rs = con.query("select * from factor_weights where id = #{factor_weights_id}")
    factor_weights_hash = rs.fetch_hash
    con.close
    sample_hash = self.to_hash
    sample_hash.delete(:id)
    sample_hash.delete(:site)
    sum = 0
    sample_hash.each do |key, value|
      sum += value * factor_weights_hash["#{key}_weight"].to_f
    end
    return sum

    # spec:
    #  sample2 = WaterSample.find(2)
    #  sample2.factor(6) #computes the 6th factor of sample #2
    #    => .0213
    # Note that the factor for this example is from data not in the sample data
    # above, that's because I want you to be sure you understand how to compute
    # this value conceptually.

  end

  # convert the object to a hash
  # if include_factors is true, include all computed factors in the hash
  def to_hash(include_factors = false)
    sample_hash = {id: self.id, site: self.site, chloroform: self.chloroform, bromoform: self.bromoform, bromodichloromethane: self.bromodichloromethane, dibromichloromethane: self.dibromichloromethane}
    if include_factors
      con = Mysql.new('localhost', 'root', '', 'factor_hw')
      rs = con.query("select id from factor_weights")
      n_rows = rs.num_rows
      n_rows.times do
        id = rs.fetch_row[0].to_i
        sample_hash.merge!({"factor_#{id}".to_sym => self.factor(id)})
      end
      con.close
    end
    return sample_hash

    # spec:
    #  sample2.to_hash
    #   => {:id =>2, :site => "North Hollywood Pump Station (well blend)", :chloroform => .00291, :bromoform => .00487, :bromodichloromethane => .00547 , :dibromichlormethane => .0109}
    # sample2.to_hash(true)
    # #let's say only 3 factors exist in our factors table, with ids of 5, 6, and 9
    #   => {:id =>2, :site => "North Hollywood Pump Station (well blend)", :chloroform => .00291, :bromoform => .00487, :bro   modichloromethane => .00547 , :dibromichlormethane => .0109, :factor_5 => .0213, :factor_6 => .0432, :factor_9 => 0.0321}

  end



end

