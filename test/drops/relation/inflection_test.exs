defmodule Drops.Relation.InflectionTest do
  use ExUnit.Case, async: true

  alias Drops.Relation.Inflection

  describe "singularize/1" do
    test "handles regular plurals ending in 's'" do
      assert Inflection.singularize("users") == "user"
      assert Inflection.singularize("posts") == "post"
      assert Inflection.singularize("comments") == "comment"
      assert Inflection.singularize("articles") == "article"
    end

    test "handles words ending in 'ies'" do
      assert Inflection.singularize("categories") == "category"
      assert Inflection.singularize("companies") == "company"
      assert Inflection.singularize("stories") == "story"
      assert Inflection.singularize("cities") == "city"
    end

    test "handles words ending in 'ves'" do
      assert Inflection.singularize("wolves") == "wolf"
      assert Inflection.singularize("lives") == "life"
      assert Inflection.singularize("knives") == "knife"
      assert Inflection.singularize("shelves") == "shelf"
    end

    test "handles words ending in 'ses'" do
      assert Inflection.singularize("glasses") == "glass"
      assert Inflection.singularize("classes") == "class"
      assert Inflection.singularize("masses") == "mass"
    end

    test "handles words ending in 'ches'" do
      assert Inflection.singularize("watches") == "watch"
      assert Inflection.singularize("matches") == "match"
      assert Inflection.singularize("patches") == "patch"
    end

    test "handles words ending in 'shes'" do
      assert Inflection.singularize("dishes") == "dish"
      assert Inflection.singularize("wishes") == "wish"
      assert Inflection.singularize("brushes") == "brush"
    end

    test "handles words ending in 'xes'" do
      assert Inflection.singularize("boxes") == "box"
      assert Inflection.singularize("foxes") == "fox"
      assert Inflection.singularize("taxes") == "tax"
    end

    test "handles words ending in 'zes'" do
      assert Inflection.singularize("quizzes") == "quiz"
      assert Inflection.singularize("prizes") == "prize"
    end

    test "handles words ending in 'oes'" do
      assert Inflection.singularize("heroes") == "hero"
      assert Inflection.singularize("potatoes") == "potato"
      assert Inflection.singularize("tomatoes") == "tomato"
    end

    test "handles irregular plurals" do
      assert Inflection.singularize("children") == "child"
      assert Inflection.singularize("feet") == "foot"
      assert Inflection.singularize("geese") == "goose"
      assert Inflection.singularize("men") == "man"
      assert Inflection.singularize("mice") == "mouse"
      assert Inflection.singularize("people") == "person"
      assert Inflection.singularize("teeth") == "tooth"
      assert Inflection.singularize("women") == "woman"
      assert Inflection.singularize("oxen") == "ox"
    end

    test "handles words that don't need singularization" do
      assert Inflection.singularize("user") == "user"
      assert Inflection.singularize("data") == "data"
      assert Inflection.singularize("information") == "information"
    end

    test "handles words ending in 'ss'" do
      assert Inflection.singularize("address") == "address"
      assert Inflection.singularize("business") == "business"
      assert Inflection.singularize("process") == "process"
    end
  end

  describe "module_to_schema_name/1" do
    test "converts simple module names" do
      assert Inflection.module_to_schema_name(MyApp.Users) == "User"
      assert Inflection.module_to_schema_name(MyApp.Posts) == "Post"
      assert Inflection.module_to_schema_name(MyApp.Comments) == "Comment"
    end

    test "converts camelCase module names to underscore" do
      assert Inflection.module_to_schema_name(MyApp.BlogPosts) == "BlogPost"
      assert Inflection.module_to_schema_name(MyApp.UserProfiles) == "UserProfile"
      assert Inflection.module_to_schema_name(MyApp.ArticleCategories) == "ArticleCategory"
    end

    test "handles complex module names" do
      assert Inflection.module_to_schema_name(MyApp.Admin.UserAccounts) == "UserAccount"
      assert Inflection.module_to_schema_name(Blog.Content.ArticleComments) == "ArticleComment"
    end

    test "handles irregular plurals in module names" do
      assert Inflection.module_to_schema_name(MyApp.People) == "Person"
      assert Inflection.module_to_schema_name(MyApp.Children) == "Child"
      assert Inflection.module_to_schema_name(MyApp.Geese) == "Goose"
    end

    test "handles module names with multiple words" do
      assert Inflection.module_to_schema_name(MyApp.HTTPRequests) == "HttpRequest"
      assert Inflection.module_to_schema_name(MyApp.XMLDocuments) == "XmlDocument"
      assert Inflection.module_to_schema_name(MyApp.APIKeys) == "ApiKey"
    end

    test "handles edge cases" do
      assert Inflection.module_to_schema_name(MyApp.Data) == "Data"
      assert Inflection.module_to_schema_name(MyApp.Information) == "Information"
      assert Inflection.module_to_schema_name(MyApp.News) == "News"
    end
  end
end
