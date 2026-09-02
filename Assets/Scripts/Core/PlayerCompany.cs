using UnityEngine;
using Renew.Economy;
using Renew.Restoration;

namespace Renew.Core
{
    public class PlayerCompany : MonoBehaviour
    {
        [SerializeField] private float startingCash = 10000f;
        [SerializeField] private Company company;
        [SerializeField] private Market market;

        public Company Company => company;
        public float Cash => company != null ? company.cash : 0f;

        private void Awake()
        {
            if (company == null)
            {
                company = new Company
                {
                    id = "player_company",
                    companyName = "Player Company",
                    cash = startingCash,
                    reputation = 0f,
                    investorConfidence = 50f
                };
                company.ownership.Add(new OwnershipStake { ownerId = "player", percentage = 100f });
            }
        }

        public bool Restore(RestorableProperty property)
        {
            if (property == null) return false;
            float cost = property.GetNextCost();
            if (cost < 0f || !company.Spend(cost)) return false;
            if (!property.RestoreNextStep(out _))
            {
                company.AddCash(cost);
                return false;
            }
            return true;
        }

        public bool RunBusiness(Business business, float customerDemand)
        {
            if (business == null || market == null) return false;
            float revenue = business.ProduceAndSell(market, customerDemand);
            company.AddCash(revenue);
            return revenue != 0f;
        }
    }
}
