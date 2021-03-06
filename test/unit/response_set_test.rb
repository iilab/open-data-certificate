require 'test_helper'

class ResponseSetTest < ActiveSupport::TestCase

  should belong_to(:dataset)
  should have_one(:certificate)

  test "creating a response set creates a certificate" do
    assert_difference "Certificate.count", 1 do
      FactoryGirl.create :response_set
    end
  end

  test "completing a response set creates a certificate" do
    assert_difference "Certificate.count" do
      FactoryGirl.create :completed_response_set
    end
  end

  test "created certificate is given the attained_level" do
    @rs = FactoryGirl.create :completed_response_set
    assert_equal @rs.certificate.attained_level, @rs.attained_level
  end

  test "can map questions to responses" do

    # add two questions, one to be the certificate
    @q1 = FactoryGirl.create :question
    @a1 = FactoryGirl.create :answer, question: @q1

    @response_set = FactoryGirl.create :response_set

    # answer the questions
    @response_1 = FactoryGirl.create :response, response_set: @response_set,
                                     :question => @q1, :answer => @a1


    @responses = @response_set.responses_for_questions [@q1]

    assert_equal [@response_1], @responses

  end

  test "Should be able to populate response_set answers from another response_set" do
    response_value = rand.to_s
    q=FactoryGirl.create(:question, reference_identifier: :question_identifier)
    a=FactoryGirl.create(:answer, reference_identifier: :answer_identifier, question: q)

    source_response_set = FactoryGirl.create(:response_set, survey: a.question.survey_section.survey)
    FactoryGirl.create :response, { response_set: source_response_set,
                                    string_value: response_value,
                                    answer_id: a.id,
                                    question_id: a.question.id }
    source_response_set.reload

    response_set = FactoryGirl.create :response_set, survey: source_response_set.survey
    response_set.reload

    response_set.copy_answers_from_response_set!(source_response_set)

    assert response_set.responses.first.try(:string_value) == response_value
  end

  def prepare_response_set(response_value = "Foo bar")
    q=FactoryGirl.create(:question, reference_identifier: :question_identifier)
    a=FactoryGirl.create(:answer, reference_identifier: :answer_identifier, question: q)

    source_response_set = FactoryGirl.create(:response_set, survey: a.question.survey_section.survey)
    FactoryGirl.create :response, { response_set: source_response_set,
                                    string_value: response_value,
                                    answer_id: a.id,
                                    question_id: a.question.id }
    source_response_set.reload
    source_response_set
  end

  test "should create a new cloned response set" do
    response_value = rand.to_s
    source_response_set = prepare_response_set(response_value)

    response_set = ResponseSet.clone_response_set(source_response_set)

    assert response_set.responses.first.try(:string_value) == response_value
  end

  test "should clone with kitten_data intact" do
    source_response_set = prepare_response_set
    source_response_set.kitten_data = KittenData.create(url: 'http://www.example.com')

    response_set = ResponseSet.clone_response_set(source_response_set)

    assert response_set.kitten_data.url == 'http://www.example.com'
  end

  test "should clone with extra attributes" do
    source_response_set = prepare_response_set
    response_set = ResponseSet.clone_response_set(source_response_set, {user_id: 123})

    assert response_set.user_id == 123
  end

  test "Should raise an error if populating response_set answers from another response_set when responses already exist" do
    response_value = rand.to_s
    q=FactoryGirl.create(:question, reference_identifier: :question_identifier)
    a=FactoryGirl.create(:answer, reference_identifier: :answer_identifier, question: q)

    source_response_set = FactoryGirl.create(:response_set, survey: a.question.survey_section.survey)
    FactoryGirl.create :response, { response_set: source_response_set,
                                    string_value: response_value,
                                    answer_id: a.id,
                                    question_id: a.question.id }
    source_response_set.reload

    response_set = FactoryGirl.create :response_set, survey: source_response_set.survey
    FactoryGirl.create :response, { response_set: response_set,
                                    string_value: 'my response',
                                    answer_id: a.id,
                                    question_id: a.question.id }
    response_set.reload

    exception = assert_raise(RuntimeError) do
      response_set.copy_answers_from_response_set!(source_response_set)
    end

    assert_equal('Attempt to over-write existing responses.', exception.message)
  end


  test "Should be able to populate response_set answers from another response_set even if the surveys are different" do
    response_value = rand.to_s
    q1=FactoryGirl.create(:question, reference_identifier: :question_identifier)
    q2=FactoryGirl.create(:question, reference_identifier: :question_identifier)

    a1=FactoryGirl.create(:answer, reference_identifier: :answer_identifier, question: q1)
    a2=FactoryGirl.create(:answer, reference_identifier: :answer_identifier, question: q2)

    source_response_set = FactoryGirl.create(:response_set, survey: a1.question.survey_section.survey)
    FactoryGirl.create :response, { response_set: source_response_set,
                                    string_value: response_value,
                                    answer_id: a1.id,
                                    question_id: a1.question.id }
    source_response_set.reload

    response_set = FactoryGirl.create :response_set, survey: a2.question.survey_section.survey
    response_set.reload
    response_set.copy_answers_from_response_set!(source_response_set)

    assert response_set.responses.first.try(:string_value) == response_value
  end

  test "#triggered_mandatory_questions should return an array of all the mandatory questions that are triggered by their dependencies for the response_set" do
    # non-mandatory question
    question = FactoryGirl.create(:question, is_mandatory: false)

    survey_section = question.survey_section
    survey = survey_section.survey

    # mandatory question, but not triggered
    mandatory_question = FactoryGirl.create(:question, is_mandatory: true, survey_section: survey_section)
    dependency = FactoryGirl.create(:dependency, question: mandatory_question)
    FactoryGirl.create :dependency_condition, dependency: dependency, operator: 'count>2'

    # triggered mandatory question
    triggered_mandatory_question = FactoryGirl.create(:question, is_mandatory: true, survey_section: survey_section)
    survey.reload

    response_set = FactoryGirl.create(:response_set, survey: survey)

    assert_equal response_set.triggered_mandatory_questions, [triggered_mandatory_question]
  end

  #TODO: need to test "all_mandatory_questions_complete?"

  test "#triggered_requirements should return an array of all the requirements that are triggered by their dependencies for the response_set" do
    survey_section = FactoryGirl.create(:survey_section)
    survey = survey_section.survey

    # non-triggered requirement
    question = FactoryGirl.create(:question, requirement: 'level_1', survey_section: survey_section)
    requirement = FactoryGirl.create(:requirement, requirement: 'level_1', survey_section: survey_section)
    dependency = FactoryGirl.create(:dependency, question: requirement)
    FactoryGirl.create :dependency_condition, question: question, dependency: dependency, operator: 'count>2'

    # non-triggered requirement
    question = FactoryGirl.create(:question, requirement: 'level_2', survey_section: survey_section)
    requirement = FactoryGirl.create(:requirement, requirement: 'level_2', survey_section: survey_section)
    dependency = FactoryGirl.create(:dependency, question: requirement)
    FactoryGirl.create :dependency_condition, question: question, dependency: dependency, operator: 'count>2'

    # triggered requirement
    question = FactoryGirl.create(:question, requirement: 'level_3', survey_section: survey_section)
    requirement = FactoryGirl.create(:requirement, requirement: 'level_3', survey_section: survey_section)
    dependency = FactoryGirl.create(:dependency, question: requirement)
    FactoryGirl.create :dependency_condition, question: question, dependency: dependency, operator: 'count<2'
    survey.reload

    response_set = FactoryGirl.create(:response_set, survey: survey)

    assert_equal response_set.triggered_requirements, [requirement]
  end

  test "#attained_level returns the correct string for the level achieved" do
    %w(none basic pilot standard exemplar).each_with_index do |level, i|
      response_set = FactoryGirl.create(:response_set)
      response_set.stubs(:minimum_outstanding_requirement_level).returns(i+1)
      assert_equal response_set.attained_level, level
    end
  end

  test "#minimum_outstanding_requirement_level returns correct value" do
    requirements = []
    Hash[*%w(5 exemplar 4 standard 3 pilot 2 basic 1 none)].each do |k, v|
      response_set = FactoryGirl.create(:response_set)
      requirements << stub(requirement_level_index: k.to_i)
      response_set.stubs(:outstanding_requirements).returns(requirements)
      assert_equal response_set.minimum_outstanding_requirement_level, k.to_i
    end
  end

  test "#minimum_outstanding_requirement_level returns exemplar index if there's no outstanding requirements" do
    response_set = FactoryGirl.create(:response_set)
    assert_equal response_set.minimum_outstanding_requirement_level, 5
  end

  test "#completed_requirements returns only triggered_requirements that are met by responses" do
    triggered_requirements = [stub(requirement: 'level_1', requirement_met_by_responses?: true),
                              stub(requirement: 'level_2', requirement_met_by_responses?: false),
                              stub(requirement: 'level_3', requirement_met_by_responses?: false),
                              stub(requirement: 'level_4', requirement_met_by_responses?: false),
    ]

    response_set = FactoryGirl.create(:response_set)
    response_set.stubs(:triggered_requirements).returns(triggered_requirements)

    assert_equal [triggered_requirements.first], response_set.completed_requirements
  end

  test "#outstanding_requirements returns only triggered_requirements that are not met by responses" do
    triggered_requirements = [stub(requirement: 'level_1', requirement_met_by_responses?: true),
                              stub(requirement: 'level_2', requirement_met_by_responses?: true),
                              stub(requirement: 'level_3', requirement_met_by_responses?: true),
                              stub(requirement: 'level_4', requirement_met_by_responses?: false),
    ]

    response_set = FactoryGirl.create(:response_set)
    response_set.stubs(:triggered_requirements).returns(triggered_requirements)

    assert_equal [triggered_requirements.last], response_set.outstanding_requirements
  end

  test "#dataset_title_determined_from_responses returns the answer of the response to the question referenced as 'dataTitle'" do
    question = FactoryGirl.create(:question, reference_identifier: 'testDataTitle')
    answer = FactoryGirl.create(:answer, question: question)
    expected_value = 'my response set title'
    response_set = FactoryGirl.create(:response_set, survey: question.survey_section.survey)
    response = FactoryGirl.create(:response, response_set: response_set, string_value: expected_value, question: question, answer: answer)

    assert_equal expected_value, response_set.dataset_title_determined_from_responses
  end

  test "#title returns the title determined from the responses if there is one" do
    question = FactoryGirl.create(:question, reference_identifier: 'testDataTitle')
    answer = FactoryGirl.create(:answer, question: question)
    expected_value = 'my response set title'
    response_set = FactoryGirl.create(:response_set, survey: question.survey_section.survey)
    response = FactoryGirl.create(:response, response_set: response_set, string_value: expected_value, question: question, answer: answer)

    assert_equal expected_value, response_set.title
  end

  test "#title returns the default title if it cannot be determined from the responses" do
    expected_value = ResponseSet::DEFAULT_TITLE
    response_set = FactoryGirl.create(:response_set)

    assert_equal expected_value, response_set.title
  end

  test "#dataset_curator_determined_from_responses returns the answer of the response to the question referenced as 'publisher'" do
    question = FactoryGirl.create(:question, reference_identifier: 'testPublisher')
    answer = FactoryGirl.create(:answer, question: question)
    expected_value = 'my curator'
    response_set = FactoryGirl.create(:response_set, survey: question.survey_section.survey)
    response = FactoryGirl.create(:response, response_set: response_set, string_value: expected_value, question: question, answer: answer)

    assert_equal expected_value, response_set.dataset_curator_determined_from_responses
  end

  test "#dataset_documentation_url_determined_from_responses returns the answer of the response to the question referenced as 'documentationUrl'" do
    question = FactoryGirl.create(:question, reference_identifier: 'testDocumentationUrl')
    answer = FactoryGirl.create(:answer, question: question)
    expected_value = 'http://example.com'
    response_set = FactoryGirl.create(:response_set, survey: question.survey_section.survey)
    response = FactoryGirl.create(:response, response_set: response_set, string_value: expected_value, question: question, answer: answer)

    assert_equal expected_value, response_set.dataset_documentation_url_determined_from_responses
  end

  test "#data_licence_determined_from_responses returns 'Not applicable' when the data licence is not applicable" do
    question = FactoryGirl.create(:question, reference_identifier: 'dataLicence')
    answer = FactoryGirl.create(:answer, question: question, reference_identifier: "na")
    expected_value = {
      :title => "Not Applicable",
      :url => nil
    }
    response_set = FactoryGirl.create(:response_set, survey: question.survey_section.survey)
    response = FactoryGirl.create(:response, response_set: response_set, question: question, answer: answer)

    assert_equal expected_value, response_set.data_licence_determined_from_responses
  end

  test "#content_licence_determined_from_responses returns 'Not applicable' when the content licence is not applicable" do
    question = FactoryGirl.create(:question, reference_identifier: 'contentLicence')
    answer = FactoryGirl.create(:answer, question: question, reference_identifier: "na")
    expected_value = {
      :title => "Not Applicable",
      :url => nil
    }
    response_set = FactoryGirl.create(:response_set, survey: question.survey_section.survey)
    response = FactoryGirl.create(:response, response_set: response_set, question: question, answer: answer)

    assert_equal expected_value, response_set.content_licence_determined_from_responses
  end

  test "#content_licence_determined_from_responses returns 'Unknown' when the content licence is not found" do
    question = FactoryGirl.create(:question, reference_identifier: 'contentLicence')
    answer = FactoryGirl.create(:answer, question: question, reference_identifier: "this-is-not-a-licence")
    expected_value = {
      :title => "Unknown",
      :url => nil
    }
    response_set = FactoryGirl.create(:response_set, survey: question.survey_section.survey)
    response = FactoryGirl.create(:response, response_set: response_set, question: question, answer: answer)

    assert_equal expected_value, response_set.content_licence_determined_from_responses
  end

  {
    "cc_by" => {
      title: "Creative Commons Attribution 4.0",
      url: "https://creativecommons.org/licenses/by/4.0/"
    },
    "cc_by_sa" => {
      title: "Creative Commons Attribution Share-Alike 4.0",
      url: "https://creativecommons.org/licenses/by-sa/4.0/"
    },
    "cc_zero" => {
      title: "CC0 1.0",
      url: "https://creativecommons.org/publicdomain/zero/1.0/"
    },
    "ogl_uk" => {
      title: "Open Government Licence 2.0 (United Kingdom)",
      url: "https://www.nationalarchives.gov.uk/doc/open-government-licence/version/2/"
    },
    "odc_by" => {
      title: "Open Data Commons Attribution License 1.0",
      url: "http://www.opendefinition.org/licenses/odc-by"
    },
     "odc_odbl" => {
       title: "Open Data Commons Open Database License 1.0",
       url: "http://www.opendefinition.org/licenses/odc-odbl"
    },
    "odc_pddl" => {
      title: "Open Data Commons Public Domain Dedication and Licence 1.0",
      url: "http://www.opendefinition.org/licenses/odc-pddl"
    }
  }.each_pair do |license, expected|
    test "#data_licence_determined_from_responses returns the correct responses when the data licence is #{license}" do
      question = FactoryGirl.create(:question, reference_identifier: 'dataLicence')
      answer = FactoryGirl.create(:answer, question: question, reference_identifier: license)
      expected_value = expected
      response_set = FactoryGirl.create(:response_set, survey: question.survey_section.survey)
      response = FactoryGirl.create(:response, response_set: response_set, question: question, answer: answer)

      assert_equal expected_value, response_set.data_licence_determined_from_responses
    end
  end

  test "#content_licence_determined_from_responses returns the correct response when the content licence is a standard licence" do
    question = FactoryGirl.create(:question, reference_identifier: 'contentLicence')
    answer = FactoryGirl.create(:answer, question: question, reference_identifier: "ogl_uk")
    expected_value = {
      :title => "Open Government Licence 2.0 (United Kingdom)",
      :url => "https://www.nationalarchives.gov.uk/doc/open-government-licence/version/2/"
    }
    response_set = FactoryGirl.create(:response_set, survey: question.survey_section.survey)
    response = FactoryGirl.create(:response, response_set: response_set, question: question, answer: answer)

    assert_equal expected_value, response_set.content_licence_determined_from_responses
  end

  test "#data_licence_determined_from_responses returns the correct response when the data licence is a non-standard licence" do
    other_data_name_question = FactoryGirl.create(:question, reference_identifier: 'otherDataLicenceName')
    other_data_name_answer = FactoryGirl.create(:answer, question: other_data_name_question)
    other_data_name = 'A made up licence'

    other_data_url_question = FactoryGirl.create(:question, reference_identifier: 'otherDataLicenceURL')
    other_data_url_answer = FactoryGirl.create(:answer, question: other_data_url_question)
    other_data_url = 'http://www.example.com/id/made-up-licence'

    question = FactoryGirl.create(:question, reference_identifier: 'dataLicence')
    answer = FactoryGirl.create(:answer, question: question, reference_identifier: "other")
    expected_value = {
      :title => other_data_name,
      :url => other_data_url
    }
    response_set = FactoryGirl.create(:response_set, survey: question.survey_section.survey)
    response = FactoryGirl.create(:response, response_set: response_set, question: question, answer: answer)
    other_data_name_response = FactoryGirl.create(:response, response_set: response_set, string_value: other_data_name, question: other_data_name_question, answer: other_data_name_answer)
    other_data_url_response = FactoryGirl.create(:response, response_set: response_set, string_value: other_data_url, question: other_data_url_question, answer: other_data_url_answer)

    assert_equal expected_value, response_set.data_licence_determined_from_responses
  end

  test "#licences returns both data and content licences" do
    rs = FactoryGirl.create(:response_set)
    rs.stubs(:data_licence_determined_from_responses).returns({title:"data"})
    rs.stubs(:content_licence_determined_from_responses).returns({title:"content"})

    expected = {
      data:    {title: "data"},
      content: {title: "content"}
    }

    assert_equal expected, rs.licences
  end

  test "#incomplete? returns true for an incomplete response_set" do
    assert_equal true, FactoryGirl.build(:response_set).incomplete?
  end

  test "#incomplete? returns false for an complete response_set" do
    assert_equal false, FactoryGirl.build(:completed_response_set).incomplete?
  end

  test "#generate_certificate creates a new certificate on save of completed response_sets" do
    # not stubbing out the attained level because the certificate reloads the response_set
    # attained_level = 'test_level'
    response_set = FactoryGirl.build(:completed_response_set)
    # response_set.stubs(:attained_level).returns(attained_level)
    assert_nil response_set.certificate
    response_set.save!

    assert_equal response_set.attained_level, response_set.certificate.try(:attained_level)
  end

  test "#generate_certificate does not overwrite existing certificate" do
    response_set = FactoryGirl.create(:completed_response_set)
    assert_not_nil certificate = response_set.certificate
    response_set.update_certificate
    assert_equal certificate, response_set.certificate
  end

  test "Should be able to assign_to_user" do
    response_set = FactoryGirl.create(:response_set, user: nil)
    user = FactoryGirl.create(:user)
    assert response_set.user.nil?
    response_set.assign_to_user!(user)

    assert_equal user, response_set.user
    assert_equal user, response_set.dataset.user
    assert_not_nil response_set.dataset
  end

  test "#newest_in_dataset? returns true for the most recent response_set" do
    dataset = FactoryGirl.build(:dataset)
    FactoryGirl.create(:response_set, dataset: dataset, created_at: Time.now.ago(1.hour))
    response_set = FactoryGirl.create(:response_set, dataset: dataset, created_at: Time.now)
    FactoryGirl.create(:response_set, dataset: dataset, created_at: Time.now.ago(3.hour))
    FactoryGirl.create(:response_set, dataset: dataset, created_at: Time.now.ago(2.hour))
    dataset.reload

    assert response_set.newest_in_dataset?
  end

  test "#newest_in_dataset? returns false when not the most recent response_set" do
    dataset = FactoryGirl.build(:dataset)
    response_set1 = FactoryGirl.create(:response_set, dataset: dataset, created_at: Time.now.ago(1.hour))
    FactoryGirl.create(:response_set, dataset: dataset, created_at: Time.now)
    response_set2 = FactoryGirl.create(:response_set, dataset: dataset, created_at: Time.now.ago(3.hour))
    response_set3 = FactoryGirl.create(:response_set, dataset: dataset, created_at: Time.now.ago(2.hour))
    dataset.reload

    [response_set1, response_set2, response_set3].each do |response_set|
      assert_false response_set.newest_in_dataset?
    end
  end

  test "#newest_completed_in_dataset? returns true for the most recent completed response_set" do
    dataset = FactoryGirl.build(:dataset)
    FactoryGirl.create(:response_set, dataset: dataset, created_at: Time.now.ago(1.hour))
    FactoryGirl.create(:response_set, dataset: dataset, created_at: Time.now.ago(3.hour))
    FactoryGirl.create(:completed_response_set, dataset: dataset, created_at: Time.now.ago(4.hour))
    FactoryGirl.create(:completed_response_set, dataset: dataset, created_at: Time.now.ago(2.hour))
    response_set = FactoryGirl.create(:completed_response_set, dataset: dataset, created_at: Time.now.ago(5.minutes))
    FactoryGirl.create(:response_set, dataset: dataset, created_at: Time.now.ago(1.minute))
    dataset.reload

    assert response_set.newest_completed_in_dataset?
  end

  test "#newest_completed_in_dataset? returns false when not the most recent completed response_set" do
    dataset = FactoryGirl.build(:dataset)
    response_set1 = FactoryGirl.create(:response_set, dataset: dataset, created_at: Time.now.ago(1.hour))
    response_set2 = FactoryGirl.create(:response_set, dataset: dataset, created_at: Time.now.ago(3.hour))
    response_set3 = FactoryGirl.create(:completed_response_set, dataset: dataset, created_at: Time.now.ago(4.hour))
    response_set4 = FactoryGirl.create(:completed_response_set, dataset: dataset, created_at: Time.now.ago(2.hour))
    FactoryGirl.create(:completed_response_set, dataset: dataset, created_at: Time.now.ago(5.minutes))
    response_set5 = FactoryGirl.create(:response_set, dataset: dataset, created_at: Time.now.ago(1.minute))
    dataset.reload

    [response_set1, response_set2, response_set3, response_set4, response_set5].each_with_index do |response_set, i|
      assert_false response_set.newest_completed_in_dataset?, "response_set#{i+1} failed assertion - created_at: #{response_set.created_at}"
    end
  end


  ### stateful things

  test "publishing a response_set published the certificate" do
    response_set = FactoryGirl.create(:response_set)

    assert_false response_set.certificate.published, "certificate starts unpublished"

    response_set.publish

    assert response_set.certificate.published, "certificate was published"
  end

  test "can't publish an unpublishable response_set" do

    # mandatory question
    question = FactoryGirl.create(:question, is_mandatory: true)
    survey_section = question.survey_section
    survey = survey_section.survey

    # which was not answered
    response_set = FactoryGirl.create(:response_set, survey: survey)

    assert !response_set.may_publish?

  end

  test "publishing a certificate populates the attained_index" do
    response_set = FactoryGirl.create(:response_set)

    assert_equal nil, response_set.attained_index

    response_set.publish!

    assert_not_equal nil, response_set.attained_index
  end

  test "all urls resolve returns true if all urls resolve sucessfully" do
    response_set = FactoryGirl.create(:response_set)
    stub_request(:get, "http://www.example.com/success").
                to_return(:body => "", status: 200)

    5.times do |n|
      question = FactoryGirl.create(:question, reference_identifier: "url_#{n}")
      answer = FactoryGirl.create(:answer, question: question, input_type: "url", )
      response = FactoryGirl.create(:response, response_set: response_set, question: question, answer: answer, string_value: "http://www.example.com/success")
    end

    assert response_set.all_urls_resolve?
  end

  test "all urls resolve returns false if some urls resolve unsucessfully" do
    response_set = FactoryGirl.create(:response_set)
    stub_request(:get, "http://www.example.com/success").
                to_return(:body => "", status: 200)
    stub_request(:get, "http://www.example.com/fail").
                to_return(:body => "", status: 404)

    2.times do |n|
      question = FactoryGirl.create(:question, reference_identifier: "url_#{n}")
      answer = FactoryGirl.create(:answer, question: question, input_type: "url", )
      response = FactoryGirl.create(:response, response_set: response_set, question: question, answer: answer, string_value: "http://www.example.com/success")
    end

    2.times do |n|
      question = FactoryGirl.create(:question, reference_identifier: "url_#{n}")
      answer = FactoryGirl.create(:answer, question: question, input_type: "url", )
      response = FactoryGirl.create(:response, response_set: response_set, question: question, answer: answer, string_value: "http://www.example.com/fail")
    end

    refute response_set.all_urls_resolve?
  end

  test "all urls resolve returns true if an explanation given" do
    response_set = FactoryGirl.create(:response_set)

    stub_request(:get, "http://www.example.com/fail").
                to_return(:body => "", status: 404)

    question = FactoryGirl.create(:question, reference_identifier: "url")
    answer = FactoryGirl.create(:answer, question: question, input_type: "url", )
    response = FactoryGirl.create(:response, response_set: response_set, question: question, answer: answer, string_value: "http://www.example.com/fail")

    response_set.stubs(:explanation_not_given?).returns(false)

    assert response_set.all_urls_resolve?
  end

end
