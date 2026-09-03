@IsTest
private class CICalculatorTest {

    @IsTest
    static void testAdd() {
        Integer result = CICalculator.add(10, 20);

        System.assertEquals(30, result);
    }
}