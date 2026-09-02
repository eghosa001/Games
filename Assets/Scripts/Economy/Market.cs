using System;
using System.Collections.Generic;
using UnityEngine;
using Renew.Core;

namespace Renew.Economy
{
    [Serializable]
    public class ResourceMarket
    {
        public ResourceType resource;
        public float basePrice = 100f;
        public float supply = 100f;
        public float demand = 100f;

        public float CurrentPrice
        {
            get
            {
                if (supply <= 0.01f) return basePrice * 3f;
                float pressure = demand / supply;
                return Mathf.Max(1f, basePrice * Mathf.Clamp(pressure, 0.25f, 3f));
            }
        }
    }

    public class Market : MonoBehaviour
    {
        [SerializeField] private List<ResourceMarket> resources = new List<ResourceMarket>();

        public IReadOnlyList<ResourceMarket> Resources => resources;

        public float GetPrice(ResourceType type)
        {
            foreach (var market in resources)
                if (market.resource == type) return market.CurrentPrice;
            return 0f;
        }

        public void AddSupply(ResourceType type, float amount)
        {
            Find(type).supply += Mathf.Max(0f, amount);
        }

        public void AddDemand(ResourceType type, float amount)
        {
            Find(type).demand += Mathf.Max(0f, amount);
        }

        public bool Buy(ResourceType type, float amount, out float totalCost)
        {
            var market = Find(type);
            amount = Mathf.Max(0f, amount);
            if (market.supply < amount)
            {
                totalCost = 0f;
                return false;
            }

            totalCost = market.CurrentPrice * amount;
            market.supply -= amount;
            return true;
        }

        private ResourceMarket Find(ResourceType type)
        {
            foreach (var market in resources)
                if (market.resource == type) return market;

            var created = new ResourceMarket { resource = type };
            resources.Add(created);
            return created;
        }
    }
}
