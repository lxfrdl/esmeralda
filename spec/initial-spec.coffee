describe "a test", ->
  it "should pass", ->
    expect("a").to.be.equal "a"

  it "will not pass", ->
    expect(true).to.be.equal false