using fake_aspnet.Controllers;
using Microsoft.AspNet.Mvc;
using Xunit;

namespace fake_dnx.tests
{
    // This project can output the Class library as a NuGet Package.
    // To enable this option, right-click on the project and select the Properties menu item. In the Build tab select "Produce outputs on build".
    public class HomeControllerTests
    {
        [Fact]
        public void Index_WhenCalled_ReturnsViewResult()
        {
            // Arrange
            var sut = new HomeController();

            // Act
            var result = sut.Index();

            // Assert
            var typed = Assert.IsType<ViewResult>(result);
            Assert.Equal("Fake App", typed.ViewData["Title"]);
        }

        [Fact]
        public void TestingTheDnxTestCommand()
        {
            Assert.True(false);
        }
    }
}