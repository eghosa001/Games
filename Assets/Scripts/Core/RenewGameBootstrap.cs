using UnityEngine;
using Renew.Economy;

namespace Renew.Core
{
    public class RenewGameBootstrap : MonoBehaviour
    {
        [SerializeField] private Market market;
        [SerializeField] private PlayerCompany playerCompany;

        private void Awake()
        {
            if (market == null) market = FindFirstObjectByType<Market>();
            if (playerCompany == null) playerCompany = FindFirstObjectByType<PlayerCompany>();

            if (market == null)
            {
                var marketObject = new GameObject("Market");
                market = marketObject.AddComponent<Market>();
            }

            if (playerCompany == null)
            {
                var playerObject = new GameObject("Player Company");
                playerCompany = playerObject.AddComponent<PlayerCompany>();
            }
        }
    }
}
