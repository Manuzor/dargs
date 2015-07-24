module dargs.tests;

import dunit;


class Tests
{
  mixin UnitTest;
  
  @Test
  void whatever()
  {
    assertEquals(1, 1);
  }

  @Test
  @Ignore("This test is ignored.")
  void ignored()
  {
    assert(false);
  }
}


mixin Main;
