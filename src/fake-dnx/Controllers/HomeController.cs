using Microsoft.AspNet.Mvc;

namespace fake_aspnet.Controllers
{
    public class HomeController : Controller
    {
        public IActionResult Index()
        {
            ViewBag.Title = "Fake App";

            return View();
        }
    }
}
